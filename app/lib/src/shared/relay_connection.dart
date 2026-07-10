import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../pairing/pairing_code.dart';
import 'pairing_auth.dart';
import 'wire.dart';

enum ConnectionStatus { searching, connected, offline }

/// A protocol-level event worth surfacing in the debug log: auth handshake
/// results, relay errors, socket lifecycle.
class RelayEvent {
  const RelayEvent(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

abstract interface class RelayTransport {
  Stream<Object?> get messages;

  /// WebSocket close code/reason once [messages] is done; null before the
  /// socket closes (or on transports without the concept).
  int? get closeCode;

  String? get closeReason;

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

  final IOWebSocketChannel _channel;

  /// Keepalive cadence mirroring the relay's 30s heartbeat: an unanswered
  /// ping closes the socket (1001), so one knob buys both path warmth and
  /// phone-side dead-path detection (keepalive spec D1/D2).
  static const pingInterval = Duration(seconds: 30);

  /// Fails a connect into a black hole (laptop asleep, wrong network) into
  /// the backoff loop instead of hanging on OS SYN retries (D3).
  static const connectTimeout = Duration(seconds: 5);

  static WebSocketRelayTransport connect(PairingCode pairing) {
    return WebSocketRelayTransport._(
      IOWebSocketChannel.connect(
        Uri.parse('ws://${pairing.host}:${pairing.port}'),
        pingInterval: pingInterval,
        connectTimeout: connectTimeout,
      ),
    );
  }

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;

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
  final _events = StreamController<RelayEvent>.broadcast();
  StreamSubscription<Object?>? _subscription;

  @override
  Stream<ConnectionStatus> get status => _status.stream;

  Stream<PayloadFrame> get payloads => _payloads.stream;

  Stream<RelayEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    _status.add(ConnectionStatus.searching);
    _subscription = transport.messages.listen(
      (message) {
        unawaited(_handleMessage(message));
      },
      onDone: () {
        // Close code tells a 1001 ping-timeout apart from a relay-initiated
        // close in the debug log (keepalive spec D7).
        final code = transport.closeCode;
        final reason = transport.closeReason;
        _events.add(
          RelayEvent(
            'Relay socket closed '
            '(code: ${code ?? 'none'}'
            '${reason != null && reason.isNotEmpty ? ', reason: $reason' : ''}).',
          ),
        );
        _status.add(ConnectionStatus.offline);
      },
      onError: (Object error) {
        _events.add(RelayEvent('Relay socket error: $error', isError: true));
        _status.add(ConnectionStatus.offline);
      },
    );
  }

  @override
  void publish(PayloadFrame frame) {
    transport.send({'v': 1, 'kind': 'publish', 'frame': frame.toJson()});
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    try {
      await transport.close();
    } on Object {
      // A transport that never finished connecting can throw on close;
      // the connection is being discarded either way.
    }
    await _status.close();
    await _payloads.close();
    await _events.close();
  }

  Future<void> _handleMessage(Object? rawMessage) async {
    final message = _decodeMessage(rawMessage);
    switch (message['kind']) {
      case 'hello':
        final challenge = _stringField(message, 'challenge');
        _events.add(const RelayEvent('Challenge received, sending proof.'));
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
        _events.add(const RelayEvent('Auth accepted by relay.'));
        _status.add(ConnectionStatus.connected);
      case 'payload':
        _payloads.add(PayloadFrame.fromJson(message['frame']));
      case 'error':
        final code = message['code'];
        final detail = message['message'];
        _events.add(
          RelayEvent(
            'Relay error${code is String ? ' [$code]' : ''}: '
            '${detail is String ? detail : 'unknown'}',
            isError: true,
          ),
        );
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
