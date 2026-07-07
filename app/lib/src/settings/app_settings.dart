class AppSettings {
  const AppSettings({
    this.showReceiveNotifications = true,
    this.showPersistentSendNotification = true,
  });

  final bool showReceiveNotifications;
  final bool showPersistentSendNotification;

  AppSettings copyWith({
    bool? showReceiveNotifications,
    bool? showPersistentSendNotification,
  }) {
    return AppSettings(
      showReceiveNotifications:
          showReceiveNotifications ?? this.showReceiveNotifications,
      showPersistentSendNotification:
          showPersistentSendNotification ?? this.showPersistentSendNotification,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.showReceiveNotifications == showReceiveNotifications &&
        other.showPersistentSendNotification == showPersistentSendNotification;
  }

  @override
  int get hashCode =>
      Object.hash(showReceiveNotifications, showPersistentSendNotification);
}
