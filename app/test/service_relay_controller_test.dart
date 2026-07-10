import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imagesync/src/foreground/service_relay_controller.dart';
import 'package:imagesync/src/pairing/pairing_code.dart';
import 'package:imagesync/src/receive/payload_receiver.dart';
import 'package:imagesync/src/receive/received_image_repository.dart';
import 'package:imagesync/src/receive/received_text_repository.dart';
import 'package:imagesync/src/settings/app_settings.dart';
import 'package:imagesync/src/shared/payload_crypto.dart';
import 'package:imagesync/src/shared/relay_connection.dart';
import 'package:imagesync/src/shared/wire.dart';

void main() {
  const pairing = PairingCode(
    host: '192.168.1.10',
    port: 17321,
    secret: 'pairing-secret',
  );

  test('reports offline and skips connecting when unpaired', () async {
    final harness = _Harness(pairing: null);

    await harness.controller.start();

    expect(harness.transports, isEmpty);
    expect(harness.emitted, [
      {'kind': 'log', 'message': 'No pairing stored; staying offline.', 'error': false},
      {'kind': 'status', 'status': 'offline'},
    ]);
    expect(harness.notifications.single.title, 'ImageSync offline');
  });

  test('connects, forwards status, and updates the notification', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    expect(
      harness.emitted,
      contains(equals({'kind': 'status', 'status': 'connected'})),
    );
    expect(
      harness.emitted,
      containsAll([
        {
          'kind': 'log',
          'message': 'Connecting to relay at 192.168.1.10:17321.',
          'error': false,
        },
        {'kind': 'log', 'message': 'Auth accepted by relay.', 'error': false},
      ]),
    );
    expect(
      harness.notifications.map((n) => n.title),
      contains('ImageSync connected'),
    );
  });

  test('forwards relay errors as error log events', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({
      'v': 1,
      'kind': 'error',
      'code': 'auth_failed',
      'message': 'Invalid proof.',
    });
    await _drain();

    expect(
      harness.emitted,
      contains(
        equals({
          'kind': 'log',
          'message': 'Relay error [auth_failed]: Invalid proof.',
          'error': true,
        }),
      ),
    );
    expect(harness.emitted.last, {'kind': 'status', 'status': 'offline'});
  });

  test('receives laptop payloads and forwards the result', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({'v': 1, 'kind': 'auth_ok'});
    transport.receive({
      'v': 1,
      'kind': 'payload',
      'frame': (await _textFrame('hello from laptop', origin: 'laptop'))
          .toJson(),
    });
    await _waitUntil(
      () => harness.emitted.any((message) => message['kind'] == 'receive'),
    );

    expect(harness.clipboard.texts, ['hello from laptop']);
    final receiveEvent = harness.emitted.firstWhere(
      (message) => message['kind'] == 'receive',
    );
    expect(receiveEvent['received'], isTrue);
    expect(receiveEvent['message'], 'Text copied from laptop.');
    expect(receiveEvent['type'], 'text');
    expect(receiveEvent['origin'], 'laptop');
    expect(receiveEvent['size'], greaterThan(0));
  });

  test('drops frames the phone itself published', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({'v': 1, 'kind': 'auth_ok'});
    transport.receive({
      'v': 1,
      'kind': 'payload',
      'frame': (await _textFrame('echo', origin: 'phone')).toJson(),
    });
    // Give a same-origin frame ample time to (wrongly) reach the receiver.
    await Future<void>.delayed(const Duration(seconds: 3));

    expect(harness.clipboard.texts, isEmpty);
    expect(
      harness.emitted.where((message) => message['kind'] == 'receive'),
      isEmpty,
    );
  });

  test('sync command tears down and reconnects with fresh pairing', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    expect(harness.transports, hasLength(1));

    await harness.controller.handleTaskData(const {'kind': 'sync'});

    expect(harness.transports, hasLength(2));
    expect(harness.transports.first.closed, isTrue);
    expect(harness.transports.last.closed, isFalse);
  });

  test('sync command goes offline when pairing was reset', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    harness.pairing = null;
    await harness.controller.handleTaskData(const {'kind': 'sync'});
    await _drain();

    expect(harness.transports.single.closed, isTrue);
    expect(harness.emitted.last, {'kind': 'status', 'status': 'offline'});
  });

  test('reconnects with backoff after the socket drops', () async {
    final harness = _Harness(
      pairing: pairing,
      reconnectBackoff: const [Duration(milliseconds: 20)],
    );

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    await transport.drop();
    await _waitUntil(() => harness.transports.length == 2);
    harness.transports.last.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    expect(harness.emitted.last, {'kind': 'status', 'status': 'connected'});
    expect(
      harness.emitted,
      contains(
        equals({
          'kind': 'log',
          'message': 'Connection lost; retrying in 0s (attempt 1).',
          'error': false,
        }),
      ),
    );
  });

  test('successful reconnect resets the backoff schedule', () async {
    final harness = _Harness(
      pairing: pairing,
      reconnectBackoff: const [
        Duration(milliseconds: 20),
        Duration(minutes: 5),
      ],
    );

    await harness.controller.start();
    harness.transports.single.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    await harness.transports.single.drop();
    await _waitUntil(() => harness.transports.length == 2);
    harness.transports.last.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    // A second drop must start over at the first (short) delay, not
    // escalate to the five-minute entry.
    await harness.transports.last.drop();
    await _waitUntil(() => harness.transports.length == 3);

    expect(
      harness.emitted
          .where(
            (message) =>
                message['kind'] == 'log' &&
                (message['message'] as String).startsWith('Connection lost'),
          )
          .map((message) => message['message']),
      everyElement(contains('(attempt 1)')),
    );
  });

  test('stop cancels a pending reconnect', () async {
    final harness = _Harness(
      pairing: pairing,
      reconnectBackoff: const [Duration(milliseconds: 20)],
    );

    await harness.controller.start();
    harness.transports.single.receive({'v': 1, 'kind': 'auth_ok'});
    await _drain();

    await harness.transports.single.drop();
    await harness.controller.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(harness.transports, hasLength(1));
  });

  test('skips the pool re-send of an already handled frame', () async {
    final harness = _Harness(
      pairing: pairing,
      reconnectBackoff: const [Duration(milliseconds: 20)],
    );
    final frame = await _textFrame('sticky payload', origin: 'laptop', ts: 7);

    await harness.controller.start();
    final transport = harness.transports.single;
    transport.receive({'v': 1, 'kind': 'auth_ok'});
    transport.receive({'v': 1, 'kind': 'payload', 'frame': frame.toJson()});
    await _waitUntil(() => harness.clipboard.texts.length == 1);

    // Drop and reconnect: the relay re-sends its current pool payload.
    await transport.drop();
    await _waitUntil(() => harness.transports.length == 2);
    final reconnected = harness.transports.last;
    reconnected.receive({'v': 1, 'kind': 'auth_ok'});
    reconnected.receive({'v': 1, 'kind': 'payload', 'frame': frame.toJson()});
    // Give the duplicate ample time to (wrongly) reach the receiver.
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(harness.clipboard.texts, ['sticky payload']);

    // A genuinely new payload still comes through.
    final fresh = await _textFrame('fresh payload', origin: 'laptop', ts: 8);
    reconnected.receive({'v': 1, 'kind': 'payload', 'frame': fresh.toJson()});
    await _waitUntil(() => harness.clipboard.texts.length == 2);

    expect(harness.clipboard.texts, ['sticky payload', 'fresh payload']);
  });

  test('stop closes the connection', () async {
    final harness = _Harness(pairing: pairing);

    await harness.controller.start();
    await harness.controller.stop();

    expect(harness.transports.single.closed, isTrue);
  });
}

Future<void> _drain() => pumpEventQueue(times: 200);

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<PayloadFrame> _textFrame(String text, {required String origin, int ts = 1}) {
  return PayloadCrypto().encrypt(
    metadata: PayloadMetadata(
      type: PayloadType.text,
      mime: 'text/plain',
      origin: origin,
      ts: ts,
    ),
    plaintext: text.codeUnits,
    pairingSecret: 'pairing-secret',
  );
}

class _Harness {
  _Harness({
    required this.pairing,
    // Effectively "never" so tests without a reconnect stay deterministic.
    List<Duration> reconnectBackoff = const [Duration(minutes: 5)],
  }) {
    controller = ServiceRelayController(
      reconnectBackoff: reconnectBackoff,
      loadPairing: () async => pairing,
      loadSettings: () async => const AppSettings(),
      connectionFactory: (pairing) {
        final transport = _FakeTransport();
        transports.add(transport);
        return RelayConnection(
          pairing: pairing,
          deviceId: 'phone',
          transport: transport,
        );
      },
      receiverFactory: (_) => PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        imageClipboard: _SilentImageClipboard(),
        notifier: _SilentNotifier(),
        receivedTextRepository: ReceivedTextRepository(
          MemoryReceivedPayloadStorage(),
        ),
        receivedImageRepository: ReceivedImageRepository(
          MemoryReceivedPayloadStorage(),
          directoryProvider: () async =>
              Directory.systemTemp.createTemp('imagesync_relay_test'),
        ),
      ),
      emit: emitted.add,
      updateNotification: (title, text) async {
        notifications.add((title: title, text: text));
      },
    );
  }

  PairingCode? pairing;
  late final ServiceRelayController controller;
  final transports = <_FakeTransport>[];
  final emitted = <Map<String, Object?>>[];
  final notifications = <({String title, String text})>[];
  final clipboard = _RecordingClipboard();
}

class _FakeTransport implements RelayTransport {
  final _messages = StreamController<Object?>.broadcast();
  bool closed = false;

  void receive(Map<String, Object?> message) => _messages.add(message);

  /// Simulates the peer vanishing: the message stream ends without the
  /// controller having asked for [close].
  Future<void> drop() => _messages.close();

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  void send(Map<String, Object?> message) {}

  @override
  Future<void> close() async {
    closed = true;
    await _messages.close();
  }
}

class _RecordingClipboard implements AndroidClipboard {
  final texts = <String>[];

  @override
  Future<void> writeText(String text) async {
    texts.add(text);
  }
}

class _SilentImageClipboard implements AndroidImageClipboard {
  @override
  Future<void> writeImage(ReceivedImage image) async {}
}

class _SilentNotifier implements PayloadNotifier {
  @override
  Future<void> showTextReceipt(String preview, {required bool copied}) async {}

  @override
  Future<void> showImageReceipt(String mime, {required bool copied}) async {}

  @override
  Future<void> showMiuiClipboardHint() async {}
}
