import 'dart:async';

import 'package:flutter/services.dart';
import 'package:screenshot_observer/screenshot_observer.dart';

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
/// Capped at 32s (keepalive spec D4): steady-state drops are rare after the
/// MIUI toggles, so the cap only bounds screen-on staleness during outages.
const defaultReconnectBackoff = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 32),
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
    this.screenshotWatcher,
    this.screenOnEvents,
    this.deviceId = 'phone',
    this.reconnectBackoff = defaultReconnectBackoff,
  });

  final ServicePairingLoader loadPairing;
  final ServiceSettingsLoader loadSettings;
  final ServiceConnectionFactory connectionFactory;
  final ServiceReceiverFactory receiverFactory;
  final ServiceEmit emit;
  final ServiceNotificationUpdate updateNotification;

  /// Optional collaborator (injected like [connectionFactory] to keep this
  /// class testable). When present, [_sync] starts it while
  /// [AppSettings.autoPushScreenshots] is on and photo access is `full`, and
  /// pauses otherwise. Its lifetime spans reconnects — only [stop] tears it
  /// down. Screenshots it emits are the push pipeline's input (#28).
  final ScreenshotWatcher? screenshotWatcher;

  /// Screen-on broadcasts from the native side (keepalive spec D5). An event
  /// while disconnected resets the backoff and reconnects immediately — the
  /// user who wakes the phone to screenshot must not wait out a 32s retry.
  /// A no-op while connected. Subscribed for the controller's whole lifetime;
  /// only [stop] cancels it.
  final Stream<void>? screenOnEvents;

  final String deviceId;
  final List<Duration> reconnectBackoff;

  RelayConnection? _connection;
  PayloadReceiveController? _receiveController;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<RelayEvent>? _eventSubscription;
  StreamSubscription<ScreenshotEvent>? _screenshotEventsSubscription;
  StreamSubscription<String>? _screenshotDiagnosticsSubscription;
  StreamSubscription<void>? _screenOnSubscription;
  ConnectionStatus _lastStatus = ConnectionStatus.offline;
  bool _screenshotWatching = false;
  bool _screenshotPaused = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = false;
  ({String origin, int ts})? _lastHandledFrame;

  Future<void> start() {
    _screenOnSubscription ??= screenOnEvents?.listen((_) => _onScreenOn());
    return _sync();
  }

  /// Screen-on trigger (keepalive spec D5): reconnect immediately if not
  /// connected, no-op when connected. The debug-log line is the phone-side
  /// timestamp for the ≤2s screen-on → auth_ok measurement (E2E §11).
  void _onScreenOn() {
    if (_stopped || _lastStatus == ConnectionStatus.connected) return;
    _log('Screen on while disconnected; reconnecting now.');
    _reconnectAttempt = 0;
    unawaited(_sync());
  }

  Future<void> handleTaskData(Object? data) async {
    if (data is Map && data['kind'] == 'sync') {
      _reconnectAttempt = 0;
      await _sync();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await _screenOnSubscription?.cancel();
    _screenOnSubscription = null;
    await _stopScreenshotWatcher();
    await _teardown();
  }

  Future<void> _sync() async {
    await _teardown();
    // The observer's lifetime tracks the setting and photo grant, not the relay
    // connection (§6: always-on while the service runs), so reconcile it before
    // the pairing check — it must keep watching even while unpaired/offline.
    final settings = await loadSettings();
    await _reconcileScreenshotWatcher(settings);
    final pairing = await loadPairing();
    if (pairing == null) {
      _log('No pairing stored; staying offline.');
      await _publishStatus(ConnectionStatus.offline);
      return;
    }
    _log('Connecting to relay at ${pairing.host}:${pairing.port}.');
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

  /// Brings the observer in line with the current settings and photo grant.
  /// Idempotent and safe to call on every [_sync] (including reconnects): a
  /// watcher already in the right state is left untouched, so the native
  /// observer isn't churned — and its start watermark isn't reset — on a
  /// reconnect.
  Future<void> _reconcileScreenshotWatcher(AppSettings settings) async {
    final watcher = screenshotWatcher;
    if (watcher == null) return;

    if (!settings.autoPushScreenshots) {
      await _stopScreenshotWatcher();
      _setScreenshotPaused(false);
      return;
    }

    final access = await watcher.accessLevel();
    if (access == ScreenshotAccessLevel.full) {
      await _startScreenshotWatcher(watcher);
    } else {
      // Setting on but access isn't full: the observer can't work (§5). Stop it
      // and surface the paused state; recovery is a Settings deep-link in the UI.
      await _stopScreenshotWatcher();
      _setScreenshotPaused(true, access: access);
    }
  }

  Future<void> _startScreenshotWatcher(ScreenshotWatcher watcher) async {
    if (_screenshotWatching) {
      _setScreenshotPaused(false);
      return;
    }
    _screenshotEventsSubscription = watcher.events.listen(_onScreenshotEvent);
    _screenshotDiagnosticsSubscription = watcher.diagnostics.listen(_log);
    try {
      await watcher.start();
      _screenshotWatching = true;
      _setScreenshotPaused(false);
      _log('Screenshot observer started.');
    } on PlatformException catch (error) {
      // Access downgraded between the check and start(); treat as paused.
      await _cancelScreenshotSubscriptions();
      _log(
        'Screenshot observer refused to start: ${error.code} '
        '(${error.message}).',
        isError: true,
      );
      _setScreenshotPaused(true);
    }
  }

  Future<void> _stopScreenshotWatcher() async {
    await _cancelScreenshotSubscriptions();
    if (!_screenshotWatching) return;
    _screenshotWatching = false;
    try {
      await screenshotWatcher?.stop();
    } catch (error) {
      _log('Screenshot observer stop failed: $error', isError: true);
    }
    _log('Screenshot observer stopped.');
  }

  Future<void> _cancelScreenshotSubscriptions() async {
    await _screenshotEventsSubscription?.cancel();
    _screenshotEventsSubscription = null;
    await _screenshotDiagnosticsSubscription?.cancel();
    _screenshotDiagnosticsSubscription = null;
  }

  /// Logs the "event emitted" stage (§7) — the observer spec's scope ends at a
  /// screenshot delivered to this isolate. The push pipeline (#28) hangs off
  /// this callback.
  void _onScreenshotEvent(ScreenshotEvent event) {
    _log(
      'Screenshot emitted: id=${event.id} name=${event.displayName} '
      'size=${event.sizeBytes} detectedAt=${event.detectedAtEpochMillis}',
    );
  }

  void _setScreenshotPaused(bool paused, {ScreenshotAccessLevel? access}) {
    if (_screenshotPaused == paused) return;
    _screenshotPaused = paused;
    emit({'kind': 'screenshotAccess', 'paused': paused, 'level': access?.name});
    if (paused) {
      _log(
        'Auto-send screenshots paused — allow all photos '
        '(access: ${access?.name ?? 'unknown'}).',
        isError: true,
      );
    }
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
    _lastStatus = status;
    emit({'kind': 'status', 'status': status.name});
    final (title, text) = _notificationCopy(status);
    await updateNotification(title, text);
  }

  (String, String) _notificationCopy(ConnectionStatus status) {
    final title = switch (status) {
      ConnectionStatus.connected => 'ImageSync connected',
      ConnectionStatus.searching => 'ImageSync connecting',
      ConnectionStatus.offline => 'ImageSync offline',
    };
    if (_screenshotPaused) {
      // The paused state is persistent and recovery-worthy (§5), so it overrides
      // the connection copy. WP7 refines this surface; the claim stays intact.
      final base = switch (status) {
        ConnectionStatus.connected => 'Receiving from the laptop.',
        ConnectionStatus.searching => 'Looking for the laptop relay...',
        ConnectionStatus.offline => 'Relay unreachable.',
      };
      return (title, '$base Auto-send screenshots paused — allow all photos.');
    }
    final text = switch (status) {
      ConnectionStatus.connected =>
        'Receiving from the laptop. Tap Send clipboard to push phone text.',
      ConnectionStatus.searching => 'Looking for the laptop relay...',
      ConnectionStatus.offline =>
        'Relay unreachable. Open the app to reconnect.',
    };
    return (title, text);
  }
}
