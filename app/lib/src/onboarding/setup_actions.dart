import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:vidyut_clipboard/vidyut_clipboard.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:screenshot_observer/screenshot_observer.dart';

import '../pairing/pairing_repository.dart';
import '../settings/app_settings_repository.dart';
import 'setup_status.dart';

/// Platform probes and grant requests behind the wizard and checklist
/// (onboarding spec D3–D5). An interface so widget tests can fake every
/// permission dialog and MIUI deep-link.
abstract interface class SetupActions {
  Future<bool> notificationsGranted();

  /// Fires the POST_NOTIFICATIONS dialog (API 33+; older APIs auto-pass).
  Future<void> requestNotifications();

  Future<ScreenshotAccessLevel> photosAccess();

  /// Fires the READ_MEDIA_IMAGES (pre-33: READ_EXTERNAL_STORAGE) dialog;
  /// verify with [photosAccess] on return.
  Future<void> requestPhotos();

  Future<bool> batteryExempt();

  /// Fires the direct ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS dialog.
  Future<void> requestBatteryExemption();

  /// ACTION_APPLICATION_DETAILS_SETTINGS — recovery when a dialog is
  /// permanently suppressed (D3).
  Future<void> openAppSettings();

  Future<bool> isMiui();

  Future<void> openAutostartSettings();

  Future<void> openBatterySaverSettings();

  Future<void> openClipboardPermissionSettings();
}

class PlatformSetupActions implements SetupActions {
  PlatformSetupActions({
    this.clipboard = const VidyutClipboard(),
    ScreenshotWatcher? screenshotWatcher,
  }) : _screenshotWatcher = screenshotWatcher ?? ChannelScreenshotWatcher();

  final VidyutClipboard clipboard;
  final ScreenshotWatcher _screenshotWatcher;

  @override
  Future<bool> notificationsGranted() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  @override
  Future<void> requestNotifications() async {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  @override
  Future<ScreenshotAccessLevel> photosAccess() =>
      _screenshotWatcher.accessLevel();

  @override
  Future<void> requestPhotos() async {
    // Maps to READ_MEDIA_IMAGES on API 33+ and the legacy storage read below;
    // the truth about what was granted comes from accessLevel(), never from
    // the request's own result (partial grants report "granted").
    await ph.Permission.photos.request();
  }

  @override
  Future<bool> batteryExempt() =>
      ph.Permission.ignoreBatteryOptimizations.isGranted;

  @override
  Future<void> requestBatteryExemption() async {
    await ph.Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  @override
  Future<bool> isMiui() => clipboard.isMiui();

  @override
  Future<void> openAutostartSettings() => clipboard.openAutostartSettings();

  @override
  Future<void> openBatterySaverSettings() =>
      clipboard.openBatterySaverSettings();

  @override
  Future<void> openClipboardPermissionSettings() =>
      clipboard.openClipboardPermissionSettings();
}

/// Composes one [SetupStatus] snapshot (D6) from the live probes and the
/// persisted self-reports.
class SetupStatusLoader {
  SetupStatusLoader({
    required this.actions,
    required this.settingsRepository,
    required this.pairingRepository,
  });

  final SetupActions actions;
  final AppSettingsRepository settingsRepository;
  final PairingRepository pairingRepository;

  Future<SetupStatus> load() async {
    final isMiui = await actions.isMiui();
    return SetupStatus(
      notificationsGranted: await actions.notificationsGranted(),
      photosAccess: await actions.photosAccess(),
      batteryExempt: await actions.batteryExempt(),
      isMiui: isMiui,
      miuiFlags: isMiui
          ? await settingsRepository.loadMiuiSetupFlags()
          : const {},
      paired: await pairingRepository.load() != null,
      onboardingComplete: await settingsRepository.onboardingComplete(),
    );
  }
}
