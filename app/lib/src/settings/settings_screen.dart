import 'package:flutter/material.dart';

import 'app_settings.dart';

typedef AppSettingsChanged = Future<void> Function(AppSettings settings);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final AppSettingsChanged onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings = widget.settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: _settings.showReceiveNotifications,
            title: const Text('Notify when laptop payloads arrive'),
            subtitle: const Text(
              'Show a notification when the laptop sends text or images to the phone.',
            ),
            onChanged: (value) => _updateSettings(
              _settings.copyWith(showReceiveNotifications: value),
            ),
          ),
          SwitchListTile(
            value: _settings.showPersistentSendNotification,
            title: const Text('Show the send clipboard notification'),
            subtitle: const Text(
              'Controls the always-available clipboard send notification for phone to laptop sync.',
            ),
            onChanged: (value) => _updateSettings(
              _settings.copyWith(showPersistentSendNotification: value),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSettings(AppSettings next) async {
    setState(() => _settings = next);
    await widget.onChanged(next);
  }
}
