import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ReceivedTextStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecureReceivedTextStorage implements ReceivedTextStorage {
  const SecureReceivedTextStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class MemoryReceivedTextStorage implements ReceivedTextStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

/// Latest-write-wins store for the newest text payload received from the
/// laptop, shared between the foreground service isolate (writer) and the
/// UI isolate (reader, on notification tap).
class ReceivedTextRepository {
  const ReceivedTextRepository(this._storage);

  static const _latestTextKey = 'imagesync.receive.latestText';

  final ReceivedTextStorage _storage;

  Future<void> saveLatest(String text) {
    return _storage.write(_latestTextKey, text);
  }

  Future<String?> loadLatest() => _storage.read(_latestTextKey);
}
