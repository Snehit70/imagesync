import 'dart:async';

import '../pairing/pairing_code.dart';
import '../receive/payload_receiver.dart';
import '../settings/app_settings.dart';
import '../shared/relay_connection.dart';

const serviceSyncCommand = {'kind': 'sync'};

typedef ServicePairingLoader = Future<PairingCode?> Function();
typedef ServiceSettingsLoader = Future<AppSettings> Function();
typedef ServiceConnectionFactory = RelayConnection Function(PairingCode pairing);
typedef ServiceReceiverFactory = PayloadReceiver Function(AppSettings settings);
typedef ServiceEmit = void Function(Map<String, Object?> message);
typedef ServiceNotificationUpdate =
    Future<void> Function(String title, String text);

/// Owns the relay connection inside the foreground service isolate.
///
/// The UI never holds the receive socket: it observes `emit`ed messages
/// (`{'kind': 'status'}` / `{'kind': 'receive'}`) and asks for reconnection
/// by sending [serviceSyncCommand] to the task.
class ServiceRelayController {
  ServiceRelayController({
    required this.loadPairing,
    required this.loadSettings,
    required this.connectionFactory,
    required this.receiverFactory,
    required this.emit,
    required this.updateNotification,
    this.deviceId = 'phone',
  });

  final ServicePairingLoader loadPairing;
  final ServiceSettingsLoader loadSettings;
  final ServiceConnectionFactory connectionFactory;
  final ServiceReceiverFactory receiverFactory;
  final ServiceEmit emit;
  final ServiceNotificationUpdate updateNotification;
  final String deviceId;

  RelayConnection? _connection;
  PayloadReceiveController? _receiveController;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<RelayEvent>? _eventSubscription;

  Future<void> start() => _sync();

  Future<void> handleTaskData(Object? data) async {
    if (data is Map && data['kind'] == 'sync') {
      await _sync();
    }
  }

  Future<void> stop() => _teardown();

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
      unawaited(_publishStatus(status));
    });
    _eventSubscription = connection.events.listen((event) {
      _log(event.message, isError: event.isError);
    });
    _receiveController = PayloadReceiveController(
      frames: connection.payloads.where((frame) => frame.origin != deviceId),
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

  Future<void> _teardown() async {
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
