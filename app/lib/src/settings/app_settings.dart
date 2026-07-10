class AppSettings {
  const AppSettings({
    this.showReceiveNotifications = true,
    this.showPersistentSendNotification = true,
    this.autoPushScreenshots = true,
  });

  final bool showReceiveNotifications;
  final bool showPersistentSendNotification;

  /// When on (and full photo access is granted), the service watches for new
  /// screenshots and auto-pushes them. UI to toggle this lands in WP6; the
  /// service reconciles the observer against this flag on every sync.
  final bool autoPushScreenshots;

  AppSettings copyWith({
    bool? showReceiveNotifications,
    bool? showPersistentSendNotification,
    bool? autoPushScreenshots,
  }) {
    return AppSettings(
      showReceiveNotifications:
          showReceiveNotifications ?? this.showReceiveNotifications,
      showPersistentSendNotification:
          showPersistentSendNotification ?? this.showPersistentSendNotification,
      autoPushScreenshots: autoPushScreenshots ?? this.autoPushScreenshots,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.showReceiveNotifications == showReceiveNotifications &&
        other.showPersistentSendNotification == showPersistentSendNotification &&
        other.autoPushScreenshots == autoPushScreenshots;
  }

  @override
  int get hashCode => Object.hash(
    showReceiveNotifications,
    showPersistentSendNotification,
    autoPushScreenshots,
  );
}
