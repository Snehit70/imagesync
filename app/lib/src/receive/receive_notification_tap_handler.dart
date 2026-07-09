import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'payload_receiver.dart';
import 'received_text_repository.dart';

/// UI-isolate handler for taps on incoming-payload notifications.
///
/// The foreground service isolate shows the notification and stores the
/// text; tapping it brings the app to the foreground, where the clipboard
/// write is always permitted. Handles both warm taps (app running) and
/// cold launches from a notification.
class ReceiveNotificationTapHandler {
  ReceiveNotificationTapHandler({
    required this.repository,
    required this.clipboard,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final ReceivedTextRepository repository;
  final AndroidClipboard clipboard;
  final FlutterLocalNotificationsPlugin _plugin;

  /// Invoked with a status message after a tap is handled.
  void Function(String message)? onCopied;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        unawaited(handleResponse(response));
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      await handleResponse(response);
    }
  }

  Future<void> handleResponse(NotificationResponse response) async {
    if (response.payload != copyLatestTextNotificationPayload) return;
    final text = await repository.loadLatest();
    if (text == null) {
      onCopied?.call('No received text to copy.');
      return;
    }
    await clipboard.writeText(text);
    onCopied?.call('Text copied from laptop.');
  }
}
