import 'package:flutter/material.dart';

import '../design/palette.dart';
import 'debug_log.dart';

class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key, required this.log});

  final DebugLog log;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug log'),
        actions: [
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_sweep, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Palette.mist,
              foregroundColor: Palette.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: log.clear,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: log,
          builder: (context, _) {
            final entries = log.entries.reversed.toList();
            if (entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Palette.petal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bug_report_outlined,
                        color: Palette.raspberry,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('No debug events yet.'),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _DebugLogTile(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DebugLogTile extends StatelessWidget {
  const _DebugLogTile({required this.entry});

  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = entry.timestamp;
    final timeLabel =
        '${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeLabel,
            style: textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Palette.muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  style: textTheme.labelSmall?.copyWith(
                    color: entry.isError ? Palette.error : Palette.raspberry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.message,
                  style: textTheme.bodySmall?.copyWith(
                    color: entry.isError ? Palette.error : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
