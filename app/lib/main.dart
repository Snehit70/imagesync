import 'dart:async';

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
import 'src/pairing/pairing_code.dart';
import 'src/pairing/pairing_repository.dart';
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
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory? relayConnectionFactory;
  final RelayDiscovery? relayDiscovery;
  final ShareSource? shareSource;
  final ReceiveNotificationTapHandler? receiveNotificationTapHandler;
  final DebugLog? debugLog;

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
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory relayConnectionFactory;
  final RelayDiscovery? relayDiscovery;
  final ShareSource? shareSource;
  final ReceiveNotificationTapHandler? receiveNotificationTapHandler;
  final DebugLog? debugLog;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
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

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
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
    if (pairing == null) await _discoverRelays();
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
        builder: (_) =>
            SettingsScreen(settings: _settings, onChanged: _updateSettings),
      ),
    );
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
                _NearbyRelaysCard(
                  relays: _nearbyRelays,
                  selected: _selectedRelay,
                  discovering: _discovering,
                  onRefresh: _discoverRelays,
                  onSelect: _selectNearbyRelay,
                ).entrance(2),
                const SizedBox(height: 28),
              ],
              _ManualPairingForm(
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

class _NearbyRelaysCard extends StatelessWidget {
  const _NearbyRelaysCard({
    required this.relays,
    required this.selected,
    required this.discovering,
    required this.onRefresh,
    required this.onSelect,
  });

  final List<DiscoveredRelay> relays;
  final DiscoveredRelay? selected;
  final bool discovering;
  final VoidCallback onRefresh;
  final ValueChanged<DiscoveredRelay> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (discovering) ...[
              const PulsingDot(size: 8),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text('Nearby relays', style: textTheme.titleMedium),
            ),
            if (!discovering)
              IconButton(
                tooltip: 'Search again',
                icon: const Icon(Icons.refresh, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Palette.mist,
                  foregroundColor: Palette.raspberry,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRefresh,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (relays.isEmpty)
          Text(
            discovering
                ? 'Searching for relays on this network…'
                : 'No relays found. Make sure the laptop relay is running, '
                      'or pair manually below.',
            style: textTheme.bodyMedium?.copyWith(color: Palette.muted),
          )
        else
          for (final relay in relays)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Palette.petal,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.dns,
                    size: 20,
                    color: Palette.raspberry,
                  ),
                ),
                title: Text(relay.name, style: textTheme.titleSmall),
                subtitle: Text(
                  '${relay.host}:${relay.port}',
                  style: textTheme.bodySmall?.copyWith(color: Palette.muted),
                ),
                trailing: relay == selected
                    ? const Icon(Icons.check_circle, color: Palette.raspberry)
                    : null,
                onTap: () => onSelect(relay),
              ),
            ),
        if (selected != null) ...[
          const SizedBox(height: 4),
          Text(
            'Enter the pairing secret below and tap Pair manually.',
            style: textTheme.bodyMedium?.copyWith(color: Palette.muted),
          ),
        ],
      ],
    );
  }
}

class _ManualPairingForm extends StatelessWidget {
  const _ManualPairingForm({
    required this.hostController,
    required this.portController,
    required this.secretController,
    required this.error,
    required this.onScanQr,
    required this.onPair,
  });

  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController secretController;
  final String? error;
  final VoidCallback onScanQr;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Manual pairing',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: hostController,
          decoration: const InputDecoration(
            labelText: 'Relay IP',
            prefixIcon: Icon(Icons.router),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: portController,
          decoration: const InputDecoration(
            labelText: 'Port',
            prefixIcon: Icon(Icons.settings_ethernet),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: secretController,
          decoration: const InputDecoration(
            labelText: 'Pairing secret',
            prefixIcon: Icon(Icons.key),
          ),
          obscureText: true,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.mist,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Palette.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Palette.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        PressableScale(
          child: FilledButton.icon(
            onPressed: onPair,
            icon: const Icon(Icons.link),
            label: const Text('Pair manually'),
          ),
        ),
        const SizedBox(height: 12),
        PressableScale(
          child: OutlinedButton.icon(
            onPressed: onScanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR'),
          ),
        ),
      ],
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
