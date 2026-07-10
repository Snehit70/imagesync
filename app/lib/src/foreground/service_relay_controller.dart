import 'dart:async';

import '../pairing/pairing_code.dart';
import '../receive/payload_receiver.dart';
import '../settings/app_settings.dart';
import '../shared/relay_connection.dart';
import '../shared/wire.dart';

const serviceSyncCommand = {'kind': 'sync'};

typedef ServicePairingLoader = Future<PairingCode?> Function();
typedef ServiceSettingsLoader = Future<AppSettings> Function();
typedef ServiceConnectionFactory = RelayConnection Function(PairingCode pairing);
typedef ServiceReceiverFactory = PayloadReceiver Function(AppSettings settings);
typedef ServiceEmit = void Function(Map<String, Object?> message);
typedef ServiceNotificationUpdate =
    Future<void> Function(String title, String text);

/// Reconnect delays after successive drops; stays at the last entry.
const defaultReconnectBackoff = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 32),
  Duration(seconds: 60),
];

/// Owns the relay connection inside the foreground service isolate.
///
/// The UI never holds the receive socket: it observes `emit`ed messages
/// (`{'kind': 'status'}` / `{'kind': 'receive'}`) and asks for reconnection
/// by sending [serviceSyncCommand] to the task.
///
/// When the socket drops (WiFi loss, relay restart) the controller
/// reconnects on its own with [reconnectBackoff]; a successful connection
/// resets the backoff. The relay re-sends the current pool payload on every
/// auth, so the frame last handled is deduplicated across reconnects.
class ServiceRelayController {
  ServiceRelayController({
    required this.loadPairing,
    required this.loadSettings,
    required this.connectionFactory,
    required this.receiverFactory,
    required this.emit,
    required this.updateNotification,
    this.deviceId = 'phone',
    this.reconnectBackoff = defaultReconnectBackoff,
  });

  final ServicePairingLoader loadPairing;
  final ServiceSettingsLoader loadSettings;
  final ServiceConnectionFactory connectionFactory;
  final ServiceReceiverFactory receiverFactory;
  final ServiceEmit emit;
  final ServiceNotificationUpdate updateNotification;
  final String deviceId;
  final List<Duration> reconnectBackoff;

  RelayConnection? _connection;
  PayloadReceiveController? _receiveController;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<RelayEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = false;
  ({String origin, int ts})? _lastHandledFrame;

  Future<void> start() => _sync();

  Future<void> handleTaskData(Object? data) async {
    if (data is Map && data['kind'] == 'sync') {
      _reconnectAttempt = 0;
      await _sync();
    }
  }

  Future<void> stop() {
    _stopped = true;
    return _teardown();
  }

  Future<void> _sync() async {
    await _teardown();
    final pairing = await loadPairing();
    if (pairing == null) {
      _log('No pairing stored; staying offline.');
      await _publishStatus(ConnectionStatus.offline);
      return;
    }
    _log('Connecting to relay at ${pairing.host}:${pairing.port}.');
    final settings = await loadSettings();
    final connection = connectionFactory(pairing);
    _connection = connection;
    _statusSubscription = connection.status.listen((status) {
      if (status == ConnectionStatus.connected) {
        _reconnectAttempt = 0;
      }
      if (status == ConnectionStatus.offline) {
        _scheduleReconnect();
      }
      unawaited(_publishStatus(status));
    });
    _eventSubscription = connection.events.listen((event) {
      _log(event.message, isError: event.isError);
    });
    _receiveController = PayloadReceiveController(
      frames: connection.payloads.where(_shouldHandleFrame),
      pairingSecret: pairing.secret,
      receiver: receiverFactory(settings),
      onResult: (frame, result) {
        emit({
          'kind': 'receive',
          'received': result.received,
          'message': result.message,
          'type': frame.type.wireName,
          'size': _payloadSizeBytes(frame.payload),
          'origin': frame.origin,
        });
      },
    )..start();
    await connection.start();
  }

  /// Drops the phone's own frames and the pool re-send that follows every
  /// reconnect: the relay pushes its current payload after each auth, so a
  /// frame with the same origin and timestamp has already been handled.
  bool _shouldHandleFrame(PayloadFrame frame) {
    if (frame.origin == deviceId) return false;
    final last = _lastHandledFrame;
    if (last != null && last.origin == frame.origin && last.ts == frame.ts) {
      return false;
    }
    _lastHandledFrame = (origin: frame.origin, ts: frame.ts);
    return true;
  }

  void _scheduleReconnect() {
    if (_stopped || _reconnectTimer != null) return;
    final delay = reconnectBackoff.isEmpty
        ? Duration.zero
        : reconnectBackoff[_reconnectAttempt.clamp(
            0,
            reconnectBackoff.length - 1,
          )];
    _reconnectAttempt += 1;
    _log(
      'Connection lost; retrying in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempt).',
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_stopped) return;
      unawaited(_sync());
    });
  }

  Future<void> _teardown() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _receiveController?.dispose();
    _receiveController = null;
    await _connection?.close();
    _connection = null;
  }

  void _log(String message, {bool isError = false}) {
    emit({'kind': 'log', 'message': message, 'error': isError});
  }

  /// Decoded size of the base64 ciphertext — the bytes that crossed the wire.
  int _payloadSizeBytes(String base64Payload) {
    final padding = base64Payload.endsWith('==')
        ? 2
        : base64Payload.endsWith('=')
        ? 1
        : 0;
    return (base64Payload.length ~/ 4) * 3 - padding;
  }

  Future<void> _publishStatus(ConnectionStatus status) async {
    emit({'kind': 'status', 'status': status.name});
    await updateNotification(
      switch (status) {
        ConnectionStatus.connected => 'ImageSync connected',
        ConnectionStatus.searching => 'ImageSync connecting',
        ConnectionStatus.offline => 'ImageSync offline',
      },
      switch (status) {
        ConnectionStatus.connected =>
          'Receiving from the laptop. Tap Send clipboard to push phone text.',
        ConnectionStatus.searching => 'Looking for the laptop relay...',
        ConnectionStatus.offline =>
          'Relay unreachable. Open the app to reconnect.',
      },
    );
  }
}
