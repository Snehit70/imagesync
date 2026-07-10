import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync_clipboard/imagesync_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? nativeHandler;

  setUp(() {
    calls.clear();
    nativeHandler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ImagesyncClipboard.channel, (call) async {
          calls.add(call);
          return nativeHandler?.call(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ImagesyncClipboard.channel, null);
  });

  test('writeText invokes the channel with the text argument', () async {
    await const ImagesyncClipboard().writeText('hello');

    expect(calls.single.method, 'writeText');
    expect(calls.single.arguments, {'text': 'hello'});
  });

  test('writeImage invokes the channel with path and mime', () async {
    await const ImagesyncClipboard().writeImage(
      path: '/data/img.png',
      mime: 'image/png',
    );

    expect(calls.single.method, 'writeImage');
    expect(calls.single.arguments, {'path': '/data/img.png', 'mime': 'image/png'});
  });

  test('openClipboardPermissionSettings invokes the channel', () async {
    await const ImagesyncClipboard().openClipboardPermissionSettings();

    expect(calls.single.method, 'openClipboardPermissionSettings');
  });

  test('a blocked write surfaces as a PlatformException with the blocked code',
      () async {
    nativeHandler = (call) => throw PlatformException(
      code: ImagesyncClipboard.blockedErrorCode,
      message: 'denied',
    );

    await expectLater(
      const ImagesyncClipboard().writeText('hello'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          ImagesyncClipboard.blockedErrorCode,
        ),
      ),
    );
  });

  test('screen-on events surface each native broadcast', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          ScreenOnEvents.defaultChannel,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              events.success(null);
              events.success(null);
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(ScreenOnEvents.defaultChannel, null);
    });

    expect(await ScreenOnEvents().events.take(2).length, 2);
  });
}
