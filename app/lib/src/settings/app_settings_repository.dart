import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_settings.dart';

abstract interface class AppSettingsStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecureAppSettingsStorage implements AppSettingsStorage {
  const SecureAppSettingsStorage([
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

class MemoryAppSettingsStorage implements AppSettingsStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class AppSettingsRepository {
  const AppSettingsRepository(this._storage);

  static const _showReceiveNotificationsKey =
      'imagesync.settings.showReceiveNotifications';
  static const _showPersistentSendNotificationKey =
      'imagesync.settings.showPersistentSendNotification';
  static const _miuiClipboardHintShownKey =
      'imagesync.settings.miuiClipboardHintShown';

  final AppSettingsStorage _storage;

  Future<AppSettings> load() async {
    final values = await Future.wait([
      _storage.read(_showReceiveNotificationsKey),
      _storage.read(_showPersistentSendNotificationKey),
    ]);
    return AppSettings(
      showReceiveNotifications: _readBool(values[0], fallback: true),
      showPersistentSendNotification: _readBool(values[1], fallback: true),
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _storage.write(
        _showReceiveNotificationsKey,
        settings.showReceiveNotifications.toString(),
      ),
      _storage.write(
        _showPersistentSendNotificationKey,
        settings.showPersistentSendNotification.toString(),
      ),
    ]);
  }

  /// Whether the one-time "MIUI blocked the clipboard write" hint has been
  /// shown. Kept out of [AppSettings]: it is service-side bookkeeping, not a
  /// user choice, and writing it alone can't clobber a concurrent [save].
  Future<bool> miuiClipboardHintShown() async {
    return _readBool(
      await _storage.read(_miuiClipboardHintShownKey),
      fallback: false,
    );
  }

  Future<void> markMiuiClipboardHintShown() {
    return _storage.write(_miuiClipboardHintShownKey, 'true');
  }
}

bool _readBool(String? value, {required bool fallback}) {
  if (value == null) return fallback;
  return value == 'true';
}
