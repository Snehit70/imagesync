import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_observer/screenshot_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelScreenshotWatcher method channel', () {
    final calls = <MethodCall>[];
    Object? Function(MethodCall call)? nativeHandler;
    final watcher = ChannelScreenshotWatcher();

    setUp(() {
      calls.clear();
      nativeHandler = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            ChannelScreenshotWatcher.defaultMethodChannel,
            (call) async {
              calls.add(call);
              return nativeHandler?.call(call);
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            ChannelScreenshotWatcher.defaultMethodChannel,
            null,
          );
    });

    test('accessLevel maps the native string to the enum', () async {
      nativeHandler = (_) => 'partial';

      expect(await watcher.accessLevel(), ScreenshotAccessLevel.partial);
      expect(calls.single.method, 'accessLevel');
    });

    test('accessLevel falls back to denied for an unknown level', () async {
      nativeHandler = (_) => 'nonsense';

      expect(await watcher.accessLevel(), ScreenshotAccessLevel.denied);
    });

    test('start invokes the start method', () async {
      await watcher.start();

      expect(calls.single.method, 'start');
    });

    test('stop invokes the stop method', () async {
      await watcher.stop();

      expect(calls.single.method, 'stop');
    });

    test('a missing full grant surfaces as no-permission', () async {
      nativeHandler = (_) =>
          throw PlatformException(code: 'no-permission', message: 'partial');

      await expectLater(
        watcher.start(),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'no-permission'),
        ),
      );
    });
  });

  group('ScreenshotEvent.fromMap', () {
    test('parses a full screenshot payload', () {
      final event = ScreenshotEvent.fromMap(const {
        'type': 'screenshot',
        'id': 12345,
        'uri': 'content://media/external/images/media/12345',
        'displayName': 'Screenshot_2026-07-10-14-03-22-123_com.foo.png',
        'mimeType': 'image/png',
        'sizeBytes': 482133,
        'dateAddedEpochSeconds': 1783608202,
        'detectedAtEpochMillis': 1783608202412,
      });

      expect(event.id, 12345);
      expect(event.uri, 'content://media/external/images/media/12345');
      expect(event.displayName, 'Screenshot_2026-07-10-14-03-22-123_com.foo.png');
      expect(event.mimeType, 'image/png');
      expect(event.sizeBytes, 482133);
      expect(event.dateAddedEpochSeconds, 1783608202);
      expect(event.detectedAtEpochMillis, 1783608202412);
    });
  });

  group('event channel split', () {
    const eventChannelName = 'vidyut/screenshot_events';
    late ChannelScreenshotWatcher watcher;

    void emitNative(List<Object?> items) {
      final codec = const StandardMethodCodec();
      for (final item in items) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              eventChannelName,
              codec.encodeSuccessEnvelope(item),
              (_) {},
            );
      }
    }

    setUp(() {
      watcher = ChannelScreenshotWatcher();
      // The mock messenger records a listener when Dart subscribes; without a
      // handler the stream still delivers messages fed via handlePlatformMessage.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(eventChannelName), (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(eventChannelName), null);
    });

    test('routes screenshot payloads to events and logs to diagnostics', () async {
      final events = <ScreenshotEvent>[];
      final logs = <String>[];
      final eventsSub = watcher.events.listen(events.add);
      final logsSub = watcher.diagnostics.listen(logs.add);
      await Future<void>.delayed(Duration.zero);

      emitNative([
        {'type': 'log', 'message': 'screenshot onChange uri=content://x'},
        {
          'type': 'screenshot',
          'id': 7,
          'uri': 'content://media/external/images/media/7',
          'displayName': 'Screenshot_1.png',
          'mimeType': 'image/png',
          'sizeBytes': 10,
          'dateAddedEpochSeconds': 1,
          'detectedAtEpochMillis': 2,
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(logs, ['screenshot onChange uri=content://x']);
      expect(events.map((e) => e.id), [7]);

      await eventsSub.cancel();
      await logsSub.cancel();
    });
  });
}
