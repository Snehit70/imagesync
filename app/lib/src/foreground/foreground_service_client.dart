typedef TaskDataCallback = void Function(Object data);

abstract interface class ForegroundServiceClient {
  Future<void> initialize();

  Future<void> requestPermissions();

  Future<bool> get isRunning;

  Future<void> start();

  Future<void> update();

  Future<void> stop();

  void addTaskDataCallback(TaskDataCallback callback);

  void removeTaskDataCallback(TaskDataCallback callback);

  Future<void> sendToTask(Object data);
}
