import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/settings/app_settings.dart';
import 'package:imagesync/src/settings/app_settings_repository.dart';

void main() {
  test('loads the default notification settings on first run', () async {
    final repository = AppSettingsRepository(MemoryAppSettingsStorage());

    expect(
      await repository.load(),
      const AppSettings(
        showReceiveNotifications: true,
        showPersistentSendNotification: true,
      ),
    );
  });

  test('persists updated notification settings', () async {
    final storage = MemoryAppSettingsStorage();
    final repository = AppSettingsRepository(storage);
    const settings = AppSettings(
      showReceiveNotifications: false,
      showPersistentSendNotification: false,
    );

    await repository.save(settings);

    expect(await AppSettingsRepository(storage).load(), settings);
  });

  test('tracks the one-time MIUI clipboard hint flag', () async {
    final storage = MemoryAppSettingsStorage();
    final repository = AppSettingsRepository(storage);

    expect(await repository.miuiClipboardHintShown(), isFalse);

    await repository.markMiuiClipboardHintShown();

    expect(await repository.miuiClipboardHintShown(), isTrue);
    expect(
      await AppSettingsRepository(storage).miuiClipboardHintShown(),
      isTrue,
    );
  });
}
