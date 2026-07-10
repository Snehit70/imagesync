import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../shared/payload_crypto.dart';
import '../shared/wire.dart';
import 'received_image_repository.dart';
import 'received_text_repository.dart';

/// Notification payload marking "tap to copy the latest received text".
const copyLatestTextNotificationPayload = 'imagesync.copy-latest-text';

/// Notification payload marking "tap to copy the latest received image".
const copyLatestImageNotificationPayload = 'imagesync.copy-latest-image';

abstract interface class AndroidClipboard {
  Future<void> writeText(String text);
}

class FlutterAndroidClipboard implements AndroidClipboard {
  const FlutterAndroidClipboard();

  @override
  Future<void> writeText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}

abstract interface class AndroidImageClipboard {
  Future<void> writeImage(ReceivedImage image);
}

/// Writes an image to the Android clipboard through the `imagesync/clipboard`
/// platform channel: the Kotlin side wraps the file in a FileProvider content
/// URI and sets it as ClipData. The channel is hosted by MainActivity, so the
/// write only succeeds from the UI isolate with the app in the foreground —
/// the notification-tap path.
class ChannelAndroidImageClipboard implements AndroidImageClipboard {
  const ChannelAndroidImageClipboard();

  static const _channel = MethodChannel('imagesync/clipboard');

  @override
  Future<void> writeImage(ReceivedImage image) {
    return _channel.invokeMethod<void>('writeImage', {
      'path': image.path,
      'mime': image.mime,
    });
  }
}

abstract interface class PayloadNotifier {
  Future<void> showTextReady(String preview);

  Future<void> showImageReady(String mime);
}

class LocalPayloadNotifier implements PayloadNotifier {
  LocalPayloadNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    this.enabled = true,
    this.requestPermissionOnInit = true,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool enabled;

  /// The foreground service isolate has no activity to anchor a permission
  /// prompt; the UI requests notification permission before starting it.
  final bool requestPermissionOnInit;
  bool _initialized = false;

  @override
  Future<void> showTextReady(String preview) async {
    await _show(
      title: 'ImageSync text ready',
      body: preview.isEmpty ? 'Tap to copy the received text.' : preview,
      payload: copyLatestTextNotificationPayload,
    );
  }

  @override
  Future<void> showImageReady(String mime) async {
    await _show(
      title: 'ImageSync image ready',
      body: 'Tap to copy the received image ($mime).',
      payload: copyLatestImageNotificationPayload,
    );
  }

  Future<void> _show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!enabled) return;
    await _ensureInitialized();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'imagesync_payloads',
          'ImageSync payloads',
          channelDescription: 'Notifications for incoming ImageSync payloads',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (requestPermissionOnInit) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }
}

class PayloadReceiveResult {
  const PayloadReceiveResult._(this.received, this.message);

  const PayloadReceiveResult.received(String message) : this._(true, message);

  const PayloadReceiveResult.failed(String message) : this._(false, message);

  final bool received;
  final String message;
}

class PayloadReceiver {
  const PayloadReceiver({
    required this.crypto,
    required this.clipboard,
    required this.imageClipboard,
    required this.notifier,
    required this.receivedTextRepository,
    required this.receivedImageRepository,
  });

  final PayloadCrypto crypto;
  final AndroidClipboard clipboard;
  final AndroidImageClipboard imageClipboard;
  final PayloadNotifier notifier;
  final ReceivedTextRepository receivedTextRepository;
  final ReceivedImageRepository receivedImageRepository;

  Future<PayloadReceiveResult> receive({
    required PayloadFrame frame,
    required String pairingSecret,
  }) async {
    try {
      final plaintext = await crypto.decrypt(
        frame: frame,
        pairingSecret: pairingSecret,
      );
      switch (frame.type) {
        case PayloadType.text:
          final text = utf8.decode(plaintext);
          await receivedTextRepository.saveLatest(text);
          final copied = await _tryWriteClipboard(text);
          await notifier.showTextReady(_preview(text));
          return PayloadReceiveResult.received(
            copied
                ? 'Text copied from laptop.'
                : 'Text received. Tap the notification to copy.',
          );
        case PayloadType.image:
          final image = await receivedImageRepository.saveLatest(
            plaintext,
            frame.mime,
          );
          final copied = await _tryWriteImageClipboard(image);
          await notifier.showImageReady(frame.mime);
          return PayloadReceiveResult.received(
            copied
                ? 'Image copied from laptop.'
                : 'Image received. Tap the notification to copy.',
          );
      }
    } on Object catch (error) {
      return PayloadReceiveResult.failed('Receive failed: $error');
    }
  }

  /// Android 10+ (and MIUI in particular) can reject clipboard writes from
  /// a background service; the notification tap is the guaranteed path.
  Future<bool> _tryWriteClipboard(String text) async {
    try {
      await clipboard.writeText(text);
      return true;
    } on Object {
      return false;
    }
  }

  /// The image channel lives on the activity engine, so this always fails in
  /// the service isolate today; kept as the same best-effort fast path as
  /// text so a future always-available host makes it light up.
  Future<bool> _tryWriteImageClipboard(ReceivedImage image) async {
    try {
      await imageClipboard.writeImage(image);
      return true;
    } on Object {
      return false;
    }
  }

  String _preview(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 80) return compact;
    return '${compact.substring(0, 77)}...';
  }
}

class PayloadReceiveController {
  PayloadReceiveController({
    required this.frames,
    required this.pairingSecret,
    required this.receiver,
    this.onResult,
  });

  final Stream<PayloadFrame> frames;
  final String pairingSecret;
  final PayloadReceiver receiver;
  final void Function(PayloadFrame frame, PayloadReceiveResult result)?
  onResult;
  StreamSubscription<PayloadFrame>? _subscription;

  void start() {
    _subscription = frames.listen((frame) {
      unawaited(_receive(frame));
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> _receive(PayloadFrame frame) async {
    final result = await receiver.receive(
      frame: frame,
      pairingSecret: pairingSecret,
    );
    onResult?.call(frame, result);
  }
}
