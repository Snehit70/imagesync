import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/foreground/foreground_service_client.dart';
import 'package:imagesync/src/foreground/foreground_service_coordinator.dart';
import 'package:imagesync/src/pairing/pairing_code.dart';
import 'package:imagesync/src/settings/app_settings.dart';

void main() {
  test('starts the foreground notification when paired and enabled', () async {
    final client = FakeForegroundServiceClient();
    final coordinator = ForegroundServiceCoordinator(client);

    await coordinator.sync(
      settings: const AppSettings(
        showReceiveNotifications: true,
        showPersistentSendNotification: true,
      ),
      pairing: const PairingCode(
        host: '192.168.1.20',
        port: 17321,
        secret: 'secret',
      ),
    );

    expect(client.started, 1);
    expect(client.stopped, 0);
    expect(client.updated, 0);
  });

  test(
    'stops the foreground notification when the toggle is disabled',
    () async {
      final client = FakeForegroundServiceClient(running: true);
      final coordinator = ForegroundServiceCoordinator(client);

      await coordinator.sync(
        settings: const AppSettings(
          showReceiveNotifications: true,
          showPersistentSendNotification: false,
        ),
        pairing: const PairingCode(
          host: '192.168.1.20',
          port: 17321,
          secret: 'secret',
        ),
      );

      expect(client.stopped, 1);
      expect(client.started, 0);
    },
  );

  test('stops the foreground notification when pairing is removed', () async {
    final client = FakeForegroundServiceClient(running: true);
    final coordinator = ForegroundServiceCoordinator(client);

    await coordinator.sync(
      settings: const AppSettings(
        showReceiveNotifications: true,
        showPersistentSendNotification: true,
      ),
      pairing: null,
    );

    expect(client.stopped, 1);
    expect(client.started, 0);
  });

  test(
    'updates the running foreground notification when still enabled',
    () async {
      final client = FakeForegroundServiceClient(running: true);
      final coordinator = ForegroundServiceCoordinator(client);

      await coordinator.sync(
        settings: const AppSettings(
          showReceiveNotifications: true,
          showPersistentSendNotification: true,
        ),
        pairing: const PairingCode(
          host: '192.168.1.20',
          port: 17321,
          secret: 'secret',
        ),
      );

      expect(client.updated, 1);
      expect(client.started, 0);
      expect(client.stopped, 0);
    },
  );
}

class FakeForegroundServiceClient implements ForegroundServiceClient {
  FakeForegroundServiceClient({this.running = false});

  bool running;
  int started = 0;
  int updated = 0;
  int stopped = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> start() async {
    started++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stopped++;
    running = false;
  }

  @override
  Future<void> update() async {
    updated++;
  }
}
