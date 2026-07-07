import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../shared/payload_crypto.dart';
import '../shared/wire.dart';

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

abstract interface class PayloadNotifier {
  Future<void> showTextReady(String preview);

  Future<void> showImageReady(String mime);
}

class LocalPayloadNotifier implements PayloadNotifier {
  LocalPayloadNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    this.enabled = true,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool enabled;
  bool _initialized = false;

  @override
  Future<void> showTextReady(String preview) async {
    await _show(
      title: 'ImageSync text ready',
      body: preview.isEmpty ? 'Text copied to clipboard.' : preview,
    );
  }

  @override
  Future<void> showImageReady(String mime) async {
    await _show(
      title: 'ImageSync image ready',
      body: '$mime received. Image clipboard support is pending.',
    );
  }

  Future<void> _show({required String title, required String body}) async {
    if (!enabled) return;
    await _ensureInitialized();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
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
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
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
    required this.notifier,
  });

  final PayloadCrypto crypto;
  final AndroidClipboard clipboard;
  final PayloadNotifier notifier;

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
          await clipboard.writeText(text);
          await notifier.showTextReady(_preview(text));
          return const PayloadReceiveResult.received(
            'Text copied from laptop.',
          );
        case PayloadType.image:
          await notifier.showImageReady(frame.mime);
          return const PayloadReceiveResult.received(
            'Image received from laptop.',
          );
      }
    } on Object catch (error) {
      return PayloadReceiveResult.failed('Receive failed: $error');
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
  final void Function(PayloadReceiveResult result)? onResult;
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
    onResult?.call(result);
  }
}
