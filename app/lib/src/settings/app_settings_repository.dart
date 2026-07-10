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
  static const _autoPushScreenshotsKey =
      'imagesync.settings.autoPushScreenshots';
  static const _enableClipboardAutoSendKey =
      'imagesync.settings.enableClipboardAutoSend';
  static const _miuiClipboardHintShownKey =
      'imagesync.settings.miuiClipboardHintShown';

  final AppSettingsStorage _storage;

  Future<AppSettings> load() async {
    final values = await Future.wait([
      _storage.read(_showReceiveNotificationsKey),
      _storage.read(_showPersistentSendNotificationKey),
      _storage.read(_autoPushScreenshotsKey),
      _storage.read(_enableClipboardAutoSendKey),
    ]);
    return AppSettings(
      showReceiveNotifications: _readBool(values[0], fallback: true),
      showPersistentSendNotification: _readBool(values[1], fallback: true),
      autoPushScreenshots: _readBool(values[2], fallback: true),
      // Default off (D1): a normal install is unaffected.
      enableClipboardAutoSend: _readBool(values[3], fallback: false),
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
      _storage.write(
        _autoPushScreenshotsKey,
        settings.autoPushScreenshots.toString(),
      ),
      _storage.write(
        _enableClipboardAutoSendKey,
        settings.enableClipboardAutoSend.toString(),
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

  static const _onboardingCompleteKey =
      'imagesync.settings.onboardingComplete';

  /// Whether the first-run wizard has been completed (onboarding spec D1).
  /// Kept out of [AppSettings] like the hint flag: it is written from its own
  /// flow and must not clobber a concurrent [save].
  Future<bool> onboardingComplete() async {
    return _readBool(
      await _storage.read(_onboardingCompleteKey),
      fallback: false,
    );
  }

  Future<void> markOnboardingComplete() {
    return _storage.write(_onboardingCompleteKey, 'true');
  }

  static String _miuiFlagKey(MiuiSetupFlag flag) =>
      'imagesync.settings.miuiSetup.${flag.name}';

  /// Self-reported MIUI setup checkboxes (onboarding spec D5). Stored per
  /// item so the service isolate can un-check just the clipboard one on a
  /// `SecurityException` without racing the UI's writes.
  Future<Map<MiuiSetupFlag, bool>> loadMiuiSetupFlags() async {
    final values = await Future.wait(
      MiuiSetupFlag.values.map((flag) => _storage.read(_miuiFlagKey(flag))),
    );
    return {
      for (final (index, flag) in MiuiSetupFlag.values.indexed)
        flag: _readBool(values[index], fallback: false),
    };
  }

  Future<void> saveMiuiSetupFlag(MiuiSetupFlag flag, bool value) {
    return _storage.write(_miuiFlagKey(flag), value.toString());
  }
}

bool _readBool(String? value, {required bool fallback}) {
  if (value == null) return fallback;
  return value == 'true';
}
