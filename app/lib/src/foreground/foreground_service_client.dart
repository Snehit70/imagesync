abstract interface class ForegroundServiceClient {
  Future<void> initialize();

  Future<void> requestPermissions();

  Future<bool> get isRunning;

  Future<void> start();

  Future<void> update();

  Future<void> stop();
}
