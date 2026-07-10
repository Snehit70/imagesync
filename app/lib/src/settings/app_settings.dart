/// The four MIUI setup items the app cannot verify (onboarding spec D5);
/// self-reported "I did this" checkboxes persisted in settings storage.
enum MiuiSetupFlag { autostart, battery, lockInRecents, clipboard }

class AppSettings {
  const AppSettings({
    this.showReceiveNotifications = true,
    this.showPersistentSendNotification = true,
    this.autoPushScreenshots = true,
    this.enableClipboardAutoSend = false,
  });

  final bool showReceiveNotifications;
  final bool showPersistentSendNotification;

  /// When on (and full photo access is granted), the service watches for new
  /// screenshots and auto-pushes them. UI to toggle this lands in WP6; the
  /// service reconciles the observer against this flag on every sync.
  final bool autoPushScreenshots;

  /// Opt-in READ_LOGS auto-text mode (read-logs-auto-text D1). Default off and
  /// *effective* only when this is on **and** `READ_LOGS` is granted; every
  /// path degrades to the manual "Send clipboard" flow otherwise. The service
  /// reconciles the auto-send watcher against this flag and the grant on every
  /// sync.
  final bool enableClipboardAutoSend;

  AppSettings copyWith({
    bool? showReceiveNotifications,
    bool? showPersistentSendNotification,
    bool? autoPushScreenshots,
    bool? enableClipboardAutoSend,
  }) {
    return AppSettings(
      showReceiveNotifications:
          showReceiveNotifications ?? this.showReceiveNotifications,
      showPersistentSendNotification:
          showPersistentSendNotification ?? this.showPersistentSendNotification,
      autoPushScreenshots: autoPushScreenshots ?? this.autoPushScreenshots,
      enableClipboardAutoSend:
          enableClipboardAutoSend ?? this.enableClipboardAutoSend,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.showReceiveNotifications == showReceiveNotifications &&
        other.showPersistentSendNotification == showPersistentSendNotification &&
        other.autoPushScreenshots == autoPushScreenshots &&
        other.enableClipboardAutoSend == enableClipboardAutoSend;
  }

  @override
  int get hashCode => Object.hash(
    showReceiveNotifications,
    showPersistentSendNotification,
    autoPushScreenshots,
    enableClipboardAutoSend,
  );
}
