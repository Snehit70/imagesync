import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/pairing/pairing_code.dart';
import 'package:imagesync/src/shared/relay_connection.dart';
import 'package:imagesync/src/shared/wire.dart';

void main() {
  test('authenticates after the relay hello challenge', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );

    await connection.start();
    transport.receive({
      'v': 1,
      'kind': 'hello',
      'challenge': 'relay-challenge',
      'maxPayloadBytes': 1024,
    });

    await expectLater(
      transport.sent,
      emits(
        containsPair('proof', 'gFce+C2P9TQ91OoLN1X06McZlUr+nxscxhSwDrBkBh4='),
      ),
    );
  });

  test('emits connected status after auth succeeds', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );

    await connection.start();
    transport.receive({'v': 1, 'kind': 'auth_ok'});

    await expectLater(connection.status, emits(ConnectionStatus.connected));
  });

  test('emits incoming payload frames', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );
    const frame = PayloadFrame(
      type: PayloadType.text,
      mime: 'text/plain',
      origin: 'laptop',
      ts: 1800000200000,
      nonce: 'nonce',
      payload: 'payload',
    );

    await connection.start();
    transport.receive({'v': 1, 'kind': 'payload', 'frame': frame.toJson()});

    await expectLater(connection.payloads, emits(frame));
  });

  test('publishes payload frames to the relay', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );
    const frame = PayloadFrame(
      type: PayloadType.text,
      mime: 'text/plain',
      origin: 'phone',
      ts: 1800000200001,
      nonce: 'nonce',
      payload: 'payload',
    );

    await connection.start();
    connection.publish(frame);

    await expectLater(
      transport.sent,
      emits({'v': 1, 'kind': 'publish', 'frame': frame.toJson()}),
    );
  });

  test('socket-closed event carries the close code and reason', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );

    await connection.start();
    final closedEvent = connection.events.firstWhere(
      (event) => event.message.startsWith('Relay socket closed'),
    );
    transport.closeCode = 1001;
    transport.closeReason = 'ping timeout';
    await transport.endIncoming();

    final event = await closedEvent;
    expect(
      event.message,
      'Relay socket closed (code: 1001, reason: ping timeout).',
    );
  });

  test('socket-closed event reports a missing close code', () async {
    final transport = FakeRelayTransport();
    final connection = RelayConnection(
      pairing: const PairingCode(
        host: '127.0.0.1',
        port: 17321,
        secret: 'pairing-secret',
      ),
      deviceId: 'phone',
      transport: transport,
    );

    await connection.start();
    final closedEvent = connection.events.firstWhere(
      (event) => event.message.startsWith('Relay socket closed'),
    );
    await transport.endIncoming();

    expect((await closedEvent).message, 'Relay socket closed (code: none).');
  });
}

class FakeRelayTransport implements RelayTransport {
  final _incoming = StreamController<Object?>();
  final _sent = StreamController<Map<String, Object?>>();

  @override
  int? closeCode;

  @override
  String? closeReason;

  Stream<Map<String, Object?>> get sent => _sent.stream;

  void receive(Map<String, Object?> message) {
    _incoming.add(jsonEncode(message));
  }

  /// Ends the message stream as a closing socket would.
  Future<void> endIncoming() => _incoming.close();

  @override
  Stream<Object?> get messages => _incoming.stream;

  @override
  void send(Map<String, Object?> message) {
    _sent.add(message);
  }

  @override
  Future<void> close() async {
    await _incoming.close();
    await _sent.close();
  }
}
