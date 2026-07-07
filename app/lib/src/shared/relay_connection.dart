import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../pairing/pairing_code.dart';
import 'pairing_auth.dart';
import 'wire.dart';

enum ConnectionStatus { searching, connected, offline }

abstract interface class RelayTransport {
  Stream<Object?> get messages;

  void send(Map<String, Object?> message);

  Future<void> close();
}

abstract interface class RelaySession {
  Stream<ConnectionStatus> get status;

  Future<void> start();

  void publish(PayloadFrame frame);

  Future<void> close();
}

class WebSocketRelayTransport implements RelayTransport {
  WebSocketRelayTransport._(this._channel);

  final WebSocketChannel _channel;

  static WebSocketRelayTransport connect(PairingCode pairing) {
    return WebSocketRelayTransport._(
      WebSocketChannel.connect(
        Uri.parse('ws://${pairing.host}:${pairing.port}'),
      ),
    );
  }

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(Map<String, Object?> message) {
    _channel.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() => _channel.sink.close();
}

class RelayConnection implements RelaySession {
  RelayConnection({
    required this.pairing,
    required this.deviceId,
    required this.transport,
  });

  final PairingCode pairing;
  final String deviceId;
  final RelayTransport transport;

  final _status = StreamController<ConnectionStatus>.broadcast();
  final _payloads = StreamController<PayloadFrame>.broadcast();
  StreamSubscription<Object?>? _subscription;

  @override
  Stream<ConnectionStatus> get status => _status.stream;

  Stream<PayloadFrame> get payloads => _payloads.stream;

  @override
  Future<void> start() async {
    _status.add(ConnectionStatus.searching);
    _subscription = transport.messages.listen(
      (message) {
        unawaited(_handleMessage(message));
      },
      onDone: () => _status.add(ConnectionStatus.offline),
      onError: (_) => _status.add(ConnectionStatus.offline),
    );
  }

  @override
  void publish(PayloadFrame frame) {
    transport.send({'v': 1, 'kind': 'publish', 'frame': frame.toJson()});
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await transport.close();
    await _status.close();
    await _payloads.close();
  }

  Future<void> _handleMessage(Object? rawMessage) async {
    final message = _decodeMessage(rawMessage);
    switch (message['kind']) {
      case 'hello':
        final challenge = _stringField(message, 'challenge');
        transport.send({
          'v': 1,
          'kind': 'auth',
          'deviceId': deviceId,
          'proof': await createPairingProof(
            pairingSecret: pairing.secret,
            challenge: challenge,
            deviceId: deviceId,
          ),
        });
      case 'auth_ok':
        _status.add(ConnectionStatus.connected);
      case 'payload':
        _payloads.add(PayloadFrame.fromJson(message['frame']));
      case 'error':
        _status.add(ConnectionStatus.offline);
      default:
        break;
    }
  }

  Map<String, Object?> _decodeMessage(Object? rawMessage) {
    if (rawMessage is String) {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, Object?>) return decoded;
    }
    if (rawMessage is Map<String, Object?>) return rawMessage;
    throw const FormatException('Relay message must be a JSON object.');
  }
}

String _stringField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a string.');
  }
  return value;
}
