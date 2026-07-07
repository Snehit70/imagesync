import '../pairing/pairing_code.dart';
import '../settings/app_settings.dart';
import 'foreground_service_client.dart';

class ForegroundServiceCoordinator {
  const ForegroundServiceCoordinator(this._client);

  final ForegroundServiceClient _client;

  Future<void> sync({
    required AppSettings settings,
    required PairingCode? pairing,
  }) async {
    final shouldRun =
        settings.showPersistentSendNotification && pairing != null;
    final running = await _client.isRunning;

    if (!shouldRun) {
      if (running) {
        await _client.stop();
      }
      return;
    }

    await _client.initialize();
    await _client.requestPermissions();

    if (running) {
      await _client.update();
      return;
    }

    await _client.start();
  }
}
