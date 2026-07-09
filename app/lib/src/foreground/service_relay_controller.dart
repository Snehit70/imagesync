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
      await _publishStatus(ConnectionStatus.offline);
      return;
    }
    final settings = await loadSettings();
    final connection = connectionFactory(pairing);
    _connection = connection;
    _statusSubscription = connection.status.listen((status) {
      unawaited(_publishStatus(status));
    });
    _receiveController = PayloadReceiveController(
      frames: connection.payloads.where((frame) => frame.origin != deviceId),
      pairingSecret: pairing.secret,
      receiver: receiverFactory(settings),
      onResult: (result) {
        emit({
          'kind': 'receive',
          'received': result.received,
          'message': result.message,
        });
      },
    )..start();
    await connection.start();
  }

  Future<void> _teardown() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    await _receiveController?.dispose();
    _receiveController = null;
    await _connection?.close();
    _connection = null;
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
