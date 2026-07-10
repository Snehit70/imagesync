import 'dart:async';

import 'package:cryptography/cryptography.dart' show Cryptography;
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:imagesync_clipboard/imagesync_clipboard.dart';
import 'package:screenshot_observer/screenshot_observer.dart';

import '../pairing/pairing_repository.dart';
import '../push/screenshot_push_controller.dart';
import '../receive/payload_receiver.dart';
import '../receive/received_image_repository.dart';
import '../receive/received_text_repository.dart';
import '../settings/app_settings_repository.dart';
import '../shared/payload_crypto.dart';
import '../shared/relay_connection.dart';
import 'foreground_service_client.dart';
import 'service_relay_controller.dart';

const sendClipboardRoute = '/send-clipboard';
const sendClipboardButtonId = 'send_clipboard';

const _notificationButtons = [
  NotificationButton(id: sendClipboardButtonId, text: 'Send clipboard'),
];

@pragma('vm:entry-point')
void startForegroundCallback() {
  // Native AES-GCM/PBKDF2 in the headless engine too, set explicitly rather
  // than trusting the Dart plugin registrant to have run in this entrypoint;
  // the screenshot_encrypted.encryptMs log verifies the native path holds
  // (push spec §4).
  Cryptography.instance = FlutterCryptography.defaultInstance;
  FlutterForegroundTask.setTaskHandler(ImageSyncForegroundTaskHandler());
}

class ImageSyncForegroundTaskHandler extends TaskHandler {
  ImageSyncForegroundTaskHandler({ServiceRelayController? controller})
    : _controller = controller ?? _relayController();

  final ServiceRelayController _controller;

  static ServiceRelayController _relayController() {
    final pairingRepository = PairingRepository(const SecurePairingStorage());
    final settingsRepository = AppSettingsRepository(
      const SecureAppSettingsStorage(),
    );
    final screenshotWatcher = ChannelScreenshotWatcher();
    // One crypto for push and receive so the memoized PBKDF2 key is shared.
    final crypto = PayloadCrypto();
    return ServiceRelayController(
      loadPairing: pairingRepository.load,
      loadSettings: settingsRepository.load,
      screenshotWatcher: screenshotWatcher,
      pushController: ScreenshotPushController(
        readImage: screenshotWatcher.readImage,
        crypto: crypto,
        emit: FlutterForegroundTask.sendDataToMain,
      ),
      screenOnEvents: ScreenOnEvents().events,
      connectionFactory: (pairing) => RelayConnection(
        pairing: pairing,
        deviceId: 'phone',
        transport: WebSocketRelayTransport.connect(pairing),
      ),
      receiverFactory: (settings) => PayloadReceiver(
        crypto: crypto,
        clipboard: const FlutterAndroidClipboard(),
        imageClipboard: const ChannelAndroidImageClipboard(),
        receivedTextRepository: const ReceivedTextRepository(
          SecureReceivedPayloadStorage(),
        ),
        receivedImageRepository: ReceivedImageRepository(
          const SecureReceivedPayloadStorage(),
        ),
        notifier: LocalPayloadNotifier(
          showSuccessReceipts: settings.showReceiveNotifications,
          requestPermissionOnInit: false,
        ),
        hasShownMiuiClipboardHint: settingsRepository.miuiClipboardHintShown,
        markMiuiClipboardHintShown:
            settingsRepository.markMiuiClipboardHintShown,
        log: (message, {isError = false}) => FlutterForegroundTask
            .sendDataToMain({
              'kind': 'log',
              'message': message,
              'error': isError,
            }),
      ),
      emit: FlutterForegroundTask.sendDataToMain,
      updateNotification: (title, text) async {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _notificationButtons,
          notificationInitialRoute: '/',
        );
      },
    );
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) {
    return _controller.start();
  }

  @override
  void onReceiveData(Object data) {
    unawaited(_controller.handleTaskData(data));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) {
    return _controller.stop();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == sendClipboardButtonId) {
      // launchApp(route) only loads the route on a cold start; the service
      // keeps the app process alive, so it's always warm here. Route via the
      // existing data channel to PairingScreen instead.
      FlutterForegroundTask.sendDataToMain({'kind': 'sendClipboard'});
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}

class ImageSyncForegroundServiceClient implements ForegroundServiceClient {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'imagesync_foreground',
        channelName: 'ImageSync clipboard',
        channelDescription:
            'Persistent clipboard sync notification for ImageSync.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  @override
  Future<void> requestPermissions() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  @override
  Future<void> start() async {
    await _requireSuccess(
      await FlutterForegroundTask.startService(
        serviceId: 17321,
        serviceTypes: [ForegroundServiceTypes.dataSync],
        notificationTitle: 'ImageSync connecting',
        notificationText: 'Looking for the laptop relay...',
        notificationButtons: _notificationButtons,
        notificationInitialRoute: '/',
        callback: startForegroundCallback,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _requireSuccess(await FlutterForegroundTask.stopService());
  }

  @override
  Future<void> update() async {
    await sendToTask(serviceSyncCommand);
  }

  @override
  void addTaskDataCallback(TaskDataCallback callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  @override
  void removeTaskDataCallback(TaskDataCallback callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  @override
  Future<void> sendToTask(Object data) async {
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(data);
    }
  }

  Future<void> _requireSuccess(ServiceRequestResult result) async {
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Foreground service request failed: $error');
    }
  }
}
