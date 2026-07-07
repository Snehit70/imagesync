import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'src/foreground/foreground_service_client.dart';
import 'src/foreground/foreground_service_coordinator.dart';
import 'src/foreground/imagesync_foreground_service.dart';
import 'src/foreground/send_clipboard_screen.dart';
import 'src/pairing/pairing_code.dart';
import 'src/pairing/pairing_repository.dart';
import 'src/receive/payload_receiver.dart';
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
      shareSource: const ReceiveSharingIntentSource(),
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
    this.shareSource,
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory? relayConnectionFactory;
  final ShareSource? shareSource;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17211B);
    const signal = Color(0xFF2F8F5B);
    const paper = Color(0xFFF6F5EF);

    return MaterialApp(
      title: 'ImageSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: signal,
          brightness: Brightness.light,
          surface: paper,
        ),
        scaffoldBackgroundColor: paper,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      onGenerateRoute: (settings) {
        final connectionFactory =
            relayConnectionFactory ?? _defaultRelayConnection;
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
            shareSource: shareSource,
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
    this.shareSource,
  });

  final AppSettingsRepository appSettingsRepository;
  final ForegroundServiceClient foregroundServiceClient;
  final PairingRepository pairingRepository;
  final RelayConnectionFactory relayConnectionFactory;
  final ShareSource? shareSource;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '17321');
  final _secretController = TextEditingController();

  PairingCode? _pairing;
  RelayConnection? _connection;
  ShareIntakeController? _shareIntakeController;
  PayloadReceiveController? _payloadReceiveController;
  AppSettings _settings = const AppSettings();
  late final ForegroundServiceCoordinator _foregroundServiceCoordinator =
      ForegroundServiceCoordinator(widget.foregroundServiceClient);
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  String? _error;
  String? _shareStatus;
  String? _receiveStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPairing();
  }

  @override
  void dispose() {
    _shareIntakeController?.dispose();
    _payloadReceiveController?.dispose();
    _connection?.close();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
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
    });
    if (pairing != null) {
      await _connect(pairing);
    }
    await _syncForegroundService();
    await _startShareIntake();
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
      });
      await _connect(pairing);
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
      });
      await _connect(pairing);
      await _syncForegroundService();
    } on PairingCodeException catch (error) {
      setState(() => _error = error.message);
    } on FormatException {
      setState(() => _error = 'QR code is not a valid ImageSync pairing code.');
    }
  }

  Future<void> _resetPairing() async {
    await _payloadReceiveController?.dispose();
    await _connection?.close();
    await widget.pairingRepository.reset();
    if (!mounted) return;
    setState(() {
      _connection = null;
      _payloadReceiveController = null;
      _connectionStatus = ConnectionStatus.offline;
      _pairing = null;
      _error = null;
      _receiveStatus = null;
    });
    await _syncForegroundService();
  }

  Future<void> _connect(PairingCode pairing) async {
    await _payloadReceiveController?.dispose();
    await _connection?.close();
    final connection = widget.relayConnectionFactory(pairing);
    if (!mounted) {
      await connection.close();
      return;
    }
    setState(() {
      _connection = connection;
      _connectionStatus = ConnectionStatus.searching;
    });
    connection.status.listen((status) {
      if (!mounted) return;
      setState(() => _connectionStatus = status);
    });
    _payloadReceiveController = PayloadReceiveController(
      frames: connection.payloads,
      pairingSecret: pairing.secret,
      receiver: PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: const FlutterAndroidClipboard(),
        notifier: LocalPayloadNotifier(
          enabled: _settings.showReceiveNotifications,
        ),
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _receiveStatus = result.message);
      },
    )..start();
    await connection.start();
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
        if (!mounted) return;
        setState(() => _shareStatus = result.message);
      },
    );
    _shareIntakeController = controller;
    await controller.start();
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
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          if (paired)
            IconButton(
              tooltip: 'Reset pairing',
              icon: const Icon(Icons.link_off),
              onPressed: _resetPairing,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusBanner(
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
            ),
            if (_shareStatus != null) ...[
              const SizedBox(height: 12),
              _ShareStatusCard(message: _shareStatus!),
            ],
            if (_receiveStatus != null) ...[
              const SizedBox(height: 12),
              _ShareStatusCard(message: _receiveStatus!),
            ],
            const SizedBox(height: 24),
            if (paired)
              FilledButton.icon(
                onPressed: _resetPairing,
                icon: const Icon(Icons.link_off),
                label: const Text('Reset pairing'),
              )
            else
              _ManualPairingForm(
                hostController: _hostController,
                portController: _portController,
                secretController: _secretController,
                error: _error,
                onScanQr: _openQrScanner,
                onPair: _saveManualPairing,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: colors.onPrimaryContainer),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStatusCard extends StatelessWidget {
  const _ShareStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.ios_share, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
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
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onPair,
          icon: const Icon(Icons.link),
          label: const Text('Pair manually'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onScanQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR'),
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
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final rawValue = capture.barcodes.firstOrNull?.rawValue;
          if (rawValue == null || rawValue.isEmpty) return;
          _handled = true;
          Navigator.of(context).pop(rawValue);
        },
      ),
    );
  }
}
