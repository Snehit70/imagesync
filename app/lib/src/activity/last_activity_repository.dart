import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'last_activity.dart';

abstract interface class LastActivityStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecureLastActivityStorage implements LastActivityStorage {
  const SecureLastActivityStorage([
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

class MemoryLastActivityStorage implements LastActivityStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

/// Latest-write-wins store for the newest sync event, read by the home
/// dashboard (ADR 0004). Persisted so "last activity" survives an app
/// restart; only ever holds one entry.
class LastActivityRepository {
  const LastActivityRepository(this._storage);

  static const _key = 'imagesync.activity.last';

  final LastActivityStorage _storage;

  Future<LastActivity?> load() async {
    return LastActivity.decode(await _storage.read(_key));
  }

  Future<void> record(LastActivity activity) {
    return _storage.write(_key, activity.encode());
  }
}
