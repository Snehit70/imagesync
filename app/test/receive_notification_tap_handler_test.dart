import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/receive/payload_receiver.dart';
import 'package:imagesync/src/receive/receive_notification_tap_handler.dart';
import 'package:imagesync/src/receive/received_text_repository.dart';

void main() {
  test('copies the latest received text when the notification is tapped',
      () async {
    final storage = MemoryReceivedTextStorage();
    final repository = ReceivedTextRepository(storage);
    await repository.saveLatest('laptop text');
    final clipboard = _FakeClipboard();
    final messages = <String>[];
    final handler = ReceiveNotificationTapHandler(
      repository: repository,
      clipboard: clipboard,
    )..onCopied = messages.add;

    await handler.handleResponse(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: copyLatestTextNotificationPayload,
      ),
    );

    expect(clipboard.text, 'laptop text');
    expect(messages.single, 'Text copied from laptop.');
  });

  test('ignores notification taps without the copy payload', () async {
    final repository = ReceivedTextRepository(MemoryReceivedTextStorage());
    await repository.saveLatest('laptop text');
    final clipboard = _FakeClipboard();
    final handler = ReceiveNotificationTapHandler(
      repository: repository,
      clipboard: clipboard,
    );

    await handler.handleResponse(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
      ),
    );

    expect(clipboard.text, isNull);
  });

  test('reports when no received text is stored yet', () async {
    final clipboard = _FakeClipboard();
    final messages = <String>[];
    final handler = ReceiveNotificationTapHandler(
      repository: ReceivedTextRepository(MemoryReceivedTextStorage()),
      clipboard: clipboard,
    )..onCopied = messages.add;

    await handler.handleResponse(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: copyLatestTextNotificationPayload,
      ),
    );

    expect(clipboard.text, isNull);
    expect(messages.single, 'No received text to copy.');
  });
}

class _FakeClipboard implements AndroidClipboard {
  String? text;

  @override
  Future<void> writeText(String text) async {
    this.text = text;
  }
}
