import 'dart:async';

import 'package:clipboard_autosend/clipboard_autosend.dart';
import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/widgets.dart';
import '../onboarding/setup_actions.dart';
import '../onboarding/setup_checklist_screen.dart';
import 'app_settings.dart';
import 'clipboard_autosend_screen.dart';

typedef AppSettingsChanged = Future<void> Function(AppSettings settings);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    this.setupLoader,
    this.clipboardAutoSendWatcher,
  });

  final AppSettings settings;
  final AppSettingsChanged onChanged;

  /// Feeds the "Setup status" row and its summary chip (onboarding spec D8);
  /// the row is hidden when null (widget tests without platform channels).
  final SetupStatusLoader? setupLoader;

  /// Backs the Advanced → Clipboard auto-send screen (read-logs-auto-text D6);
  /// the advanced row is hidden when null (widget tests without channels).
  final ClipboardAutoSendWatcher? clipboardAutoSendWatcher;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings = widget.settings;
  int? _issueCount;

  @override
  void initState() {
    super.initState();
    unawaited(_loadIssueCount());
  }

  Future<void> _loadIssueCount() async {
    final loader = widget.setupLoader;
    if (loader == null) return;
    final status = await loader.load();
    if (mounted) setState(() => _issueCount = status.issueCount);
  }

  Future<void> _openChecklist() async {
    final loader = widget.setupLoader;
    if (loader == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SetupChecklistScreen(loader: loader)),
    );
    await _loadIssueCount();
  }

  Future<void> _openClipboardAutoSend() async {
    final watcher = widget.clipboardAutoSendWatcher;
    if (watcher == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClipboardAutoSendScreen(
          settings: _settings,
          onChanged: _updateSettings,
          watcher: watcher,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              value: _settings.autoPushScreenshots,
              title: const Text('Auto-send screenshots'),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Push new screenshots to the laptop as you take them. '
                  'Needs full photos access.',
                ),
              ),
              onChanged: (value) => _updateSettings(
                _settings.copyWith(autoPushScreenshots: value),
              ),
            ),
          ).entrance(0),
          if (widget.setupLoader != null) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                title: const Text('Setup status'),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Permissions, battery, and Xiaomi switches.'),
                ),
                trailing: _SummaryChip(issueCount: _issueCount),
                onTap: () => unawaited(_openChecklist()),
              ),
            ).entrance(1),
          ],
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              value: _settings.showReceiveNotifications,
              title: const Text('Notify when laptop payloads arrive'),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Show a receipt when something arrives from the laptop. '
                  'Delivery-failure notices always show.',
                ),
              ),
              onChanged: (value) => _updateSettings(
                _settings.copyWith(showReceiveNotifications: value),
              ),
            ),
          ).entrance(2),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              value: _settings.showPersistentSendNotification,
              title: const Text('Background sync'),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Keeps the laptop link alive for clipboard, screenshots, '
                  'and receive — shows a persistent notification. Off stops '
                  'all syncing.',
                ),
              ),
              onChanged: (value) => _updateSettings(
                _settings.copyWith(showPersistentSendNotification: value),
              ),
            ),
          ).entrance(3),
          if (widget.clipboardAutoSendWatcher != null) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                title: const Text('Advanced'),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Clipboard auto-send for text — one-time computer setup, '
                    'not for every phone.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Palette.muted),
                onTap: () => unawaited(_openClipboardAutoSend()),
              ),
            ).entrance(4),
          ],
        ],
      ),
    );
  }

  Future<void> _updateSettings(AppSettings next) async {
    setState(() => _settings = next);
    await widget.onChanged(next);
  }
}

/// Green check when all-clear, "N issues" pill otherwise (D8).
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.issueCount});

  final int? issueCount;

  @override
  Widget build(BuildContext context) {
    final count = issueCount;
    if (count == null) return const SizedBox.shrink();
    if (count == 0) {
      return const Icon(Icons.check_circle, color: Palette.raspberry);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.petal,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          count == 1 ? '1 issue' : '$count issues',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Palette.raspberry),
        ),
      ),
    );
  }
}
