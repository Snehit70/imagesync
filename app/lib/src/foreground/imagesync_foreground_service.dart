import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground_service_client.dart';

const sendClipboardRoute = '/send-clipboard';
const sendClipboardButtonId = 'send_clipboard';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(ImageSyncForegroundTaskHandler());
}

class ImageSyncForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == sendClipboardButtonId) {
      FlutterForegroundTask.launchApp(sendClipboardRoute);
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
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
            'Persistent clipboard send notification for ImageSync.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
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
        notificationTitle: 'ImageSync is ready',
        notificationText:
            'Tap Send clipboard to push phone text to the laptop.',
        notificationButtons: const [
          NotificationButton(id: sendClipboardButtonId, text: 'Send clipboard'),
        ],
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
    await _requireSuccess(
      await FlutterForegroundTask.updateService(
        notificationTitle: 'ImageSync is ready',
        notificationText:
            'Tap Send clipboard to push phone text to the laptop.',
        notificationButtons: const [
          NotificationButton(id: sendClipboardButtonId, text: 'Send clipboard'),
        ],
        notificationInitialRoute: '/',
        callback: startForegroundCallback,
      ),
    );
  }

  Future<void> _requireSuccess(ServiceRequestResult result) async {
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Foreground service request failed: $error');
    }
  }
}
