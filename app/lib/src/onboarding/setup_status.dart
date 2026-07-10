import 'package:screenshot_observer/screenshot_observer.dart';

import '../settings/app_settings.dart';

/// One snapshot of every setup item (onboarding spec D6) — the single source
/// of truth behind the wizard, the checklist, and the home banner. Recomputed
/// on app resume and after every wizard step.
class SetupStatus {
  const SetupStatus({
    required this.notificationsGranted,
    required this.photosAccess,
    required this.batteryExempt,
    required this.isMiui,
    required this.miuiFlags,
    required this.paired,
    required this.onboardingComplete,
  });

  final bool notificationsGranted;
  final ScreenshotAccessLevel photosAccess;
  final bool batteryExempt;
  final bool isMiui;

  /// Self-reported D5 checkboxes; only meaningful when [isMiui].
  final Map<MiuiSetupFlag, bool> miuiFlags;
  final bool paired;
  final bool onboardingComplete;

  bool miuiFlagDone(MiuiSetupFlag flag) => miuiFlags[flag] ?? false;

  /// Everything not green, MIUI self-reports included — the Settings summary
  /// chip ("2 issues") and checklist count.
  int get issueCount {
    var count = 0;
    if (!notificationsGranted) count++;
    if (photosAccess != ScreenshotAccessLevel.full) count++;
    if (!batteryExempt) count++;
    if (isMiui) {
      count += MiuiSetupFlag.values.where((flag) => !miuiFlagDone(flag)).length;
    }
    if (!paired) count++;
    return count;
  }

  /// Whether the home banner should show (D1): a live-verifiable item is
  /// unhealthy while the feature it backs is enabled. MIUI self-reports don't
  /// trigger the banner — the app can't verify them.
  bool bannerNeeded(AppSettings settings) {
    if (!onboardingComplete) return true;
    if (settings.autoPushScreenshots &&
        photosAccess != ScreenshotAccessLevel.full) {
      return true;
    }
    if (!notificationsGranted &&
        (settings.showReceiveNotifications ||
            settings.showPersistentSendNotification)) {
      return true;
    }
    if (settings.showPersistentSendNotification && !batteryExempt) return true;
    return false;
  }

  /// The banner's headline (D1): "Finish setup" until the wizard is done,
  /// then the most actionable degradation.
  String bannerLabel(AppSettings settings) {
    if (!onboardingComplete) return 'Finish setup';
    if (settings.autoPushScreenshots &&
        photosAccess != ScreenshotAccessLevel.full) {
      return 'Auto-push paused — allow all photos';
    }
    if (!notificationsGranted) return 'Notifications are off';
    return 'Battery exemption revoked — sync may pause';
  }
}
