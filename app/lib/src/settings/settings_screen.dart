import 'dart:async';

import 'package:clipboard_autosend/clipboard_autosend.dart';
import 'package:flutter/material.dart';

import '../debug/debug_log.dart';
import '../debug/debug_log_screen.dart';
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
    this.debugLog,
    this.paired = false,
    this.onForgetPairing,
  });

  final AppSettings settings;
  final AppSettingsChanged onChanged;

  /// Feeds the "Setup status" row and its summary chip (onboarding spec D8);
  /// the row is hidden when null (widget tests without platform channels).
  final SetupStatusLoader? setupLoader;

  /// Backs the Advanced → Clipboard auto-send screen (read-logs-auto-text D6);
  /// the advanced row is hidden when null (widget tests without channels).
  final ClipboardAutoSendWatcher? clipboardAutoSendWatcher;

  /// The in-app debug log, opened from the Setup section (ADR 0004); the row
  /// is hidden when null.
  final DebugLog? debugLog;

  /// Whether a pairing exists — gates the "Forget this laptop" danger row
  /// (ADR 0005).
  final bool paired;

  /// Deletes the saved pairing; run behind a confirmation in the danger zone.
  final Future<void> Function()? onForgetPairing;

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

  Future<void> _openDebugLog() async {
    final log = widget.debugLog;
    if (log == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DebugLogScreen(log: log)),
    );
  }

  Future<void> _confirmForget() async {
    final onForget = widget.onForgetPairing;
    if (onForget == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.ground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: const Text('Forget this laptop?'),
        content: const Text(
          "ImageSync will delete this pairing. You'll need to pair again — "
          'by QR or manually — to sync with your laptop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Palette.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.error),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onForget();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    var step = 0;
    int next() => step++;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Master switch, first and alone: it governs all syncing (ADR 0006).
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              value: _settings.showPersistentSendNotification,
              title: const Text('Sync with laptop'),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Keeps the laptop link alive for clipboard, screenshots, '
                  'and receive — shows a persistent notification. Off '
                  'disconnects and stops all syncing.',
                ),
              ),
              onChanged: (value) => _updateSettings(
                _settings.copyWith(showPersistentSendNotification: value),
              ),
            ),
          ).entrance(next()),
          const _SectionHeader('Sync'),
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
          ).entrance(next()),
          const _SectionHeader('Notifications'),
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
          ).entrance(next()),
          const _SectionHeader('Setup'),
          if (widget.setupLoader != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
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
            ).entrance(next()),
          if (widget.clipboardAutoSendWatcher != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
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
            ).entrance(next()),
          if (widget.debugLog != null)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                title: const Text('Debug log'),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Timestamped connection and payload events.'),
                ),
                trailing: const Icon(Icons.chevron_right, color: Palette.muted),
                onTap: () => unawaited(_openDebugLog()),
              ),
            ).entrance(next()),
          if (widget.paired && widget.onForgetPairing != null) ...[
            const _SectionHeader('Danger zone'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                leading: const Icon(Icons.link_off, color: Palette.error),
                title: const Text(
                  'Forget this laptop',
                  style: TextStyle(color: Palette.error),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Delete this pairing and stop syncing.'),
                ),
                onTap: () => unawaited(_confirmForget()),
              ),
            ).entrance(next()),
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

/// Muted section label — the only typographic hierarchy in the flat UI
/// (ADR 0006). Kept low-key so the calm surface language holds.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Palette.muted),
      ),
    );
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
