import 'dart:async';

import 'package:cryptography/cryptography.dart' show Cryptography;
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'src/debug/debug_log.dart';
import 'src/design/palette.dart';
import 'src/design/theme.dart';
import 'src/design/widgets.dart';
import 'src/debug/debug_log_screen.dart';
import 'src/foreground/foreground_service_client.dart';
import 'src/foreground/foreground_service_coordinator.dart';
import 'src/foreground/imagesync_foreground_service.dart';
import 'src/foreground/send_clipboard_screen.dart';
import 'src/onboarding/onboarding_wizard.dart';
import 'src/onboarding/setup_actions.dart';
import 'src/onboarding/setup_checklist_screen.dart';
import 'src/onboarding/setup_status.dart';
import 'src/pairing/pairing_code.dart';
import 'src/pairing/pairing_repository.dart';
import 'src/pairing/pairing_widgets.dart';
import 'src/pairing/relay_discovery.dart';
import 'src/receive/payload_receiver.dart';
import 'src/receive/receive_notification_tap_handler.dart';
import 'src/receive/received_image_repository.dart';
import 'src/receive/received_text_repository.dart';
import 'src/share/share_intake_controller.dart';
import 'src/share/share_publisher.dart';
import 'src/settings/app_settings.dart';
import 'src/settings/app_settings_repository.dart';
import 'src/settings/settings_screen.dart';
import 'src/share/share_source.dart';
import 'src/shared/payload_crypto.dart';
import 'src/shared/relay_connection.dart';

typedef RelayConnectionFactory = RelayConnection Function(PairingCode pairing);

void main() {
  // Delegate AES-GCM/PBKDF2 to platform crypto (push spec §4); the package
  // silently falls back to pure Dart where the plugin channel is missing.
  Cryptography.instance = FlutterCryptography.defaultInstance;
  FlutterForegroundTask.initCommunicationPort();
  runApp(
    ImageSyncApp(
      appSettingsRepository: AppSettingsRepository(
        const SecureAppSettingsStorage(),
      ),
      foregroundServiceClient: ImageSyncForegroundServiceClient(),
      pairingRepository: PairingRepository(const SecurePairingStorage()),
      relayDiscovery: RelayDiscovery(lock: const ChannelMulticastLock()),
      shareSource: const ReceiveSharingIntentSource(),
      receiveNotificationTapHandler: ReceiveNotificationTapHandler(
        repository: const ReceivedTextRepository(
          SecureReceivedPayloadStorage(),
        ),
        imageRepository: ReceivedImageRepository(
          const SecureReceivedPayloadStorage(),
        ),
        clipboard: const FlutterAndroidClipboard(),
        imageClipboard: const ChannelAndroidImageClipboard(),
      ),
      setupActions: PlatformSetupActions(),
    ),
  );
}

class ImageSyncApp extends StatelessWidget {
  const ImageSyncApp({
    super.key,
    required this.appSettingsRepository,
    required this.foregroundServiceClient,
    required this.pairingRepository,
    this.relayConnectionFactory,
    this.relayDiscovery,
    this.shareSource,
    this.receiveNotificationTapHandler,
    this.debugLog,
    this.setupActions,
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory? relayConnectionFactory;
  final RelayDiscovery? relayDiscovery;
  final ShareSource? shareSource;
  final ReceiveNotificationTapHandler? receiveNotificationTapHandler;
  final DebugLog? debugLog;

  /// Platform probes behind onboarding and the setup checklist. When null
  /// (widget tests without platform channels) the wizard, banner, and
  /// Setup-status row are disabled.
  final SetupActions? setupActions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImageSync',
      theme: buildImageSyncTheme(),
      onGenerateRoute: (settings) {
        final connectionFactory =
            relayConnectionFactory ?? _defaultRelayConnection;
        final log = debugLog ?? sharedDebugLog;
        if (settings.name == sendClipboardRoute) {
          return MaterialPageRoute(
            builder: (_) => SendClipboardScreen(
              clipboardReader: const FlutterClipboardReader(),
              publisher: SharePublisherAdapter(
                SharePublisher(
                  pairingRepository: pairingRepository,
                  relaySessionFactory: connectionFactory,
                  crypto: PayloadCrypto(),
                  fileReader: const LocalShareFileReader(),
                ),
              ),
              debugLog: log,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => PairingScreen(
            appSettingsRepository: appSettingsRepository,
            foregroundServiceClient: foregroundServiceClient,
            pairingRepository: pairingRepository,
            relayConnectionFactory: connectionFactory,
            relayDiscovery: relayDiscovery,
            shareSource: shareSource,
            receiveNotificationTapHandler: receiveNotificationTapHandler,
            debugLog: log,
            setupActions: setupActions,
          ),
          settings: settings,
        );
      },
    );
  }
}

RelayConnection _defaultRelayConnection(PairingCode pairing) {
  return RelayConnection(
    pairing: pairing,
    deviceId: 'phone',
    transport: WebSocketRelayTransport.connect(pairing),
  );
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.appSettingsRepository,
    required this.foregroundServiceClient,
    required this.pairingRepository,
    required this.relayConnectionFactory,
    this.relayDiscovery,
    this.shareSource,
    this.receiveNotificationTapHandler,
    this.debugLog,
    this.setupActions,
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory relayConnectionFactory;
  final RelayDiscovery? relayDiscovery;
  final ShareSource? shareSource;
  final ReceiveNotificationTapHandler? receiveNotificationTapHandler;
  final DebugLog? debugLog;
  final SetupActions? setupActions;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with WidgetsBindingObserver {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '17321');
  final _secretController = TextEditingController();

  PairingCode? _pairing;
  List<DiscoveredRelay> _nearbyRelays = const [];
  DiscoveredRelay? _selectedRelay;
  bool _discovering = false;
  ShareIntakeController? _shareIntakeController;
  AppSettings _settings = const AppSettings();
  late final ForegroundServiceCoordinator _foregroundServiceCoordinator =
      ForegroundServiceCoordinator(widget.foregroundServiceClient);
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  String? _error;
  String? _shareStatus;
  String? _receiveStatus;
  bool _loading = true;
  late final DebugLog _debugLog = widget.debugLog ?? sharedDebugLog;

  /// Live "connected" flag mirrored into the wizard's finale (D2).
  final _connectedNotifier = ValueNotifier<bool>(false);
  SetupStatus? _setupStatus;

  /// D6 loader shared by the banner, the checklist, and the Settings chip.
  late final SetupStatusLoader? _setupLoader = widget.setupActions == null
      ? null
      : SetupStatusLoader(
          actions: widget.setupActions!,
          settingsRepository: widget.appSettingsRepository,
          pairingRepository: widget.pairingRepository,
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.foregroundServiceClient.addTaskDataCallback(_onServiceData);
    final tapHandler = widget.receiveNotificationTapHandler;
    if (tapHandler != null) {
      tapHandler.onCopied = (message) {
        _debugLog.add('clipboard', message);
        if (mounted) setState(() => _receiveStatus = message);
      };
      unawaited(tapHandler.init());
    }
    _loadPairing();
  }

  /// Recompute the D6 snapshot on resume so the home banner tracks external
  /// changes (revoking photos in system settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshSetupStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectedNotifier.dispose();
    widget.foregroundServiceClient.removeTaskDataCallback(_onServiceData);
    _shareIntakeController?.dispose();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _onServiceData(Object data) {
    if (data is! Map || !mounted) return;
    switch (data['kind']) {
      case 'status':
        final status = ConnectionStatus.values
            .where((value) => value.name == data['status'])
            .firstOrNull;
        if (status != null) {
          _debugLog.add(
            'connection',
            'Status: ${status.name}',
            isError: status == ConnectionStatus.offline,
          );
          _connectedNotifier.value = status == ConnectionStatus.connected;
          setState(() => _connectionStatus = status);
        }
      case 'receive':
        final message = data['message'];
        if (message is String) {
          _debugLog.add(
            'receive',
            _describeReceive(data, message),
            isError: data['received'] == false,
          );
          setState(() => _receiveStatus = message);
        }
      case 'log':
        final message = data['message'];
        if (message is String) {
          _debugLog.add('service', message, isError: data['error'] == true);
        }
      case 'sendClipboard':
        Navigator.of(context).pushNamed(sendClipboardRoute);
    }
  }

  String _describeReceive(Map<Object?, Object?> data, String message) {
    final type = data['type'];
    final size = data['size'];
    final origin = data['origin'];
    if (type is! String || size is! int || origin is! String) return message;
    return '$type (${_formatBytes(size)}) from $origin — $message';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _loadPairing() async {
    final results = await Future.wait<Object?>([
      widget.pairingRepository.load(),
      widget.appSettingsRepository.load(),
    ]);
    final pairing = results[0] as PairingCode?;
    final settings = results[1] as AppSettings;
    if (!mounted) return;
    setState(() {
      _pairing = pairing;
      _settings = settings;
      _loading = false;
      if (pairing != null) _connectionStatus = ConnectionStatus.searching;
    });
    await _syncForegroundService();
    await _startShareIntake();
    await _refreshSetupStatus();
    if (_setupLoader != null &&
        !(await widget.appSettingsRepository.onboardingComplete())) {
      // First run: the wizard is the whole surface until finished or skipped
      // through; gated by onboardingComplete, never force-re-shown (D1).
      if (mounted) await _openWizard();
      return;
    }
    if (pairing == null) await _discoverRelays();
  }

  Future<void> _refreshSetupStatus() async {
    final loader = _setupLoader;
    if (loader == null) return;
    final status = await loader.load();
    if (mounted) setState(() => _setupStatus = status);
  }

  Future<void> _openWizard() async {
    final actions = widget.setupActions;
    if (actions == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingWizard(
          actions: actions,
          settingsRepository: widget.appSettingsRepository,
          relayDiscovery: widget.relayDiscovery,
          connectionStatus: _connectedNotifier,
          onScanQr: () => Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const QrPairingScreen()),
          ),
          savePairing: (pairing) async {
            await widget.pairingRepository.save(pairing);
            if (mounted) {
              setState(() {
                _pairing = pairing;
                _error = null;
                _connectionStatus = ConnectionStatus.searching;
              });
            }
            await _syncForegroundService();
            return null;
          },
        ),
      ),
    );
    await _refreshSetupStatus();
    if (_pairing == null) await _discoverRelays();
  }

  Future<void> _openChecklist() async {
    final loader = _setupLoader;
    if (loader == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SetupChecklistScreen(loader: loader)),
    );
    await _refreshSetupStatus();
  }

  Future<void> _discoverRelays() async {
    final discovery = widget.relayDiscovery;
    if (discovery == null || _discovering) return;
    setState(() => _discovering = true);
    List<DiscoveredRelay>? relays;
    try {
      relays = await discovery.discover();
    } on Exception {
      // Discovery is best-effort; manual pairing and QR remain available.
    }
    if (!mounted) return;
    setState(() {
      _discovering = false;
      if (relays != null) _nearbyRelays = relays;
    });
  }

  void _selectNearbyRelay(DiscoveredRelay relay) {
    _hostController.text = relay.host;
    _portController.text = relay.port.toString();
    setState(() => _selectedRelay = relay);
  }

  Future<void> _saveManualPairing() async {
    try {
      final pairing = PairingCode.parseManual(
        host: _hostController.text,
        port: _portController.text,
        secret: _secretController.text,
      );
      await widget.pairingRepository.save(pairing);
      if (!mounted) return;
      setState(() {
        _pairing = pairing;
        _error = null;
        _connectionStatus = ConnectionStatus.searching;
      });
      await _syncForegroundService();
    } on PairingCodeException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _openQrScanner() async {
    final rawCode = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrPairingScreen()));
    if (rawCode == null) return;
    try {
      final pairing = PairingCode.parse(rawCode);
      await widget.pairingRepository.save(pairing);
      if (!mounted) return;
      setState(() {
        _pairing = pairing;
        _error = null;
        _connectionStatus = ConnectionStatus.searching;
      });
      await _syncForegroundService();
    } on PairingCodeException catch (error) {
      setState(() => _error = error.message);
    } on FormatException {
      setState(() => _error = 'QR code is not a valid ImageSync pairing code.');
    }
  }

  Future<void> _resetPairing() async {
    await widget.pairingRepository.reset();
    if (!mounted) return;
    setState(() {
      _connectionStatus = ConnectionStatus.offline;
      _pairing = null;
      _error = null;
      _receiveStatus = null;
      _selectedRelay = null;
    });
    await _syncForegroundService();
    await _discoverRelays();
  }

  Future<void> _startShareIntake() async {
    final source = widget.shareSource;
    if (source == null) return;
    await _shareIntakeController?.dispose();
    final controller = ShareIntakeController(
      source: source,
      publisher: SharePublisher(
        pairingRepository: widget.pairingRepository,
        relaySessionFactory: widget.relayConnectionFactory,
        crypto: PayloadCrypto(),
        fileReader: const LocalShareFileReader(),
      ),
      onResult: (result) {
        _debugLog.add('send', result.message, isError: !result.published);
        if (!mounted) return;
        setState(() => _shareStatus = result.message);
      },
    );
    _shareIntakeController = controller;
    await controller.start();
  }

  Future<void> _openDebugLog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DebugLogScreen(log: _debugLog)),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: _settings,
          onChanged: _updateSettings,
          setupLoader: _setupLoader,
        ),
      ),
    );
    await _refreshSetupStatus();
  }

  Future<void> _updateSettings(AppSettings settings) async {
    await widget.appSettingsRepository.save(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
    await _syncForegroundService();
  }

  Future<void> _syncForegroundService() {
    return _foregroundServiceCoordinator.sync(
      settings: _settings,
      pairing: _pairing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final paired = _pairing != null;
    final statusLabel = switch (_connectionStatus) {
      ConnectionStatus.connected => 'Connected',
      ConnectionStatus.searching => 'Searching',
      ConnectionStatus.offline => paired ? 'Offline' : 'Unpaired',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('ImageSync'),
        actions: [
          _AppBarAction(
            tooltip: 'Debug log',
            icon: Icons.bug_report_outlined,
            onPressed: _openDebugLog,
          ),
          _AppBarAction(
            tooltip: 'Settings',
            icon: Icons.settings_outlined,
            onPressed: _openSettings,
          ),
          if (paired)
            _AppBarAction(
              tooltip: 'Reset pairing',
              icon: Icons.link_off,
              onPressed: _resetPairing,
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusHero(
              label: statusLabel,
              description: paired
                  ? 'Paired with ${_pairing!.host}:${_pairing!.port}.'
                  : 'Pair with the laptop relay to join the clipboard pool.',
              icon: switch (_connectionStatus) {
                ConnectionStatus.connected => Icons.link,
                ConnectionStatus.searching => Icons.wifi_find,
                ConnectionStatus.offline =>
                  paired ? Icons.cloud_off : Icons.qr_code_scanner,
              },
              searching: _connectionStatus == ConnectionStatus.searching,
            ).entrance(0),
            if (_setupStatus?.bannerNeeded(_settings) ?? false) ...[
              const SizedBox(height: 16),
              _SetupBanner(
                label: _setupStatus!.bannerLabel(_settings),
                onTap: () => unawaited(
                  _setupStatus!.onboardingComplete
                      ? _openChecklist()
                      : _openWizard(),
                ),
              ).entrance(1),
            ],
            if (_shareStatus != null) ...[
              const SizedBox(height: 12),
              _ShareStatusCard(message: _shareStatus!).entrance(1),
            ],
            if (_receiveStatus != null) ...[
              const SizedBox(height: 12),
              _ShareStatusCard(message: _receiveStatus!).entrance(1),
            ],
            const SizedBox(height: 28),
            if (paired)
              PressableScale(
                child: FilledButton.icon(
                  onPressed: _resetPairing,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Reset pairing'),
                ),
              ).entrance(2)
            else ...[
              if (widget.relayDiscovery != null) ...[
                NearbyRelaysCard(
                  relays: _nearbyRelays,
                  selected: _selectedRelay,
                  discovering: _discovering,
                  onRefresh: _discoverRelays,
                  onSelect: _selectNearbyRelay,
                ).entrance(2),
                const SizedBox(height: 28),
              ],
              ManualPairingForm(
                hostController: _hostController,
                portController: _portController,
                secretController: _secretController,
                error: _error,
                onScanQr: _openQrScanner,
                onPair: _saveManualPairing,
              ).entrance(3),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: PressableScale(
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 20, color: Palette.ink),
          style: IconButton.styleFrom(
            backgroundColor: Palette.mist,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.label,
    required this.description,
    required this.icon,
    required this.searching,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 16),
        MorphingBlob(
          size: 180,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Palette.raspberry),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (searching) ...[
              const PulsingDot(),
              const SizedBox(width: 6),
            ],
            Text(label, style: textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: Palette.muted),
          ),
        ),
      ],
    );
  }
}

class _ShareStatusCard extends StatelessWidget {
  const _ShareStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Palette.petal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ios_share,
                size: 18,
                color: Palette.raspberry,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home banner (onboarding spec D1): "Finish setup" while onboarding is
/// incomplete, or the most actionable degradation afterwards. Tapping opens
/// the wizard resp. the checklist.
class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: Palette.petal,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.tune,
                  size: 20,
                  color: Palette.raspberry,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Palette.raspberry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QrPairingScreen extends StatefulWidget {
  const QrPairingScreen({super.key});

  @override
  State<QrPairingScreen> createState() => _QrPairingScreenState();
}

class _QrPairingScreenState extends State<QrPairingScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final rawValue = capture.barcodes.firstOrNull?.rawValue;
              if (rawValue == null || rawValue.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(rawValue);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Palette.petal,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Text(
                    'Point at the QR code on the laptop',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
