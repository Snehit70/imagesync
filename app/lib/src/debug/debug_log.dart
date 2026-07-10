import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A single debug event: connection state, auth result, payload event, error.
@immutable
class DebugLogEntry {
  const DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.isError = false,
  });

  final DateTime timestamp;
  final String category;
  final String message;
  final bool isError;
}

/// In-memory ring buffer of debug events for the in-app debug view.
///
/// Lives in the UI isolate: service-isolate events arrive over the task data
/// channel and are appended here by the UI. Nothing is persisted — the log
/// exists to debug the live session.
class DebugLog extends ChangeNotifier {
  DebugLog({this.capacity = 200, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() clock;
  final _entries = ListQueue<DebugLogEntry>();

  /// Entries oldest-first.
  List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  void add(String category, String message, {bool isError = false}) {
    _entries.addLast(
      DebugLogEntry(
        timestamp: clock(),
        category: category,
        message: message,
        isError: isError,
      ),
    );
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}

/// App-wide log shared by every screen; injectable copies are for tests.
final sharedDebugLog = DebugLog();
