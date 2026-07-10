import 'dart:async';

import 'package:flutter/services.dart';

/// Grant state for the media-read permission that backs the observer.
///
/// Only [full] sustains a background [ContentObserver]: a partial "Select
/// photos" grant still fires `onChange` but silently filters query results to
/// the user-picked set, so a brand-new screenshot is never visible (spec §5).
enum ScreenshotAccessLevel {
  full,
  partial,
  denied;

  static ScreenshotAccessLevel fromName(String? name) {
    return switch (name) {
      'full' => ScreenshotAccessLevel.full,
      'partial' => ScreenshotAccessLevel.partial,
      _ => ScreenshotAccessLevel.denied,
    };
  }
}

/// A screenshot the native observer detected in MediaStore (spec §3).
///
/// [uri] is `ContentUris.withAppendedId(EXTERNAL_CONTENT_URI, id)` — the handle
/// the push pipeline (#28) opens the bytes with. [detectedAtEpochMillis] minus
/// the screenshot's capture time is the observer-latency half of the ≤2s bar.
class ScreenshotEvent {
  const ScreenshotEvent({
    required this.id,
    required this.uri,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.dateAddedEpochSeconds,
    required this.detectedAtEpochMillis,
  });

  final int id;
  final String uri;
  final String displayName;
  final String mimeType;
  final int sizeBytes;
  final int dateAddedEpochSeconds;
  final int detectedAtEpochMillis;

  factory ScreenshotEvent.fromMap(Map<Object?, Object?> map) {
    return ScreenshotEvent(
      id: (map['id'] as num).toInt(),
      uri: map['uri'] as String,
      displayName: map['displayName'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      dateAddedEpochSeconds: (map['dateAddedEpochSeconds'] as num?)?.toInt() ?? 0,
      detectedAtEpochMillis: (map['detectedAtEpochMillis'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'ScreenshotEvent(id: $id, displayName: $displayName, '
      'sizeBytes: $sizeBytes, detectedAtEpochMillis: $detectedAtEpochMillis)';
}

/// Dart face of the screenshot observer plugin.
///
/// The native side registers the observing state in a process-wide singleton
/// from application context (spec §1), so the service isolate controls a single
/// observer for the process lifetime regardless of which engine attaches.
abstract interface class ScreenshotWatcher {
  /// The current media-read grant level (spec §5). Safe to call from any
  /// isolate — it touches no observer state.
  Future<ScreenshotAccessLevel> accessLevel();

  /// Begins watching MediaStore. Throws a [PlatformException] with code
  /// `no-permission` (detail = the detected [ScreenshotAccessLevel] name) when
  /// the full grant is absent; idempotent otherwise.
  Future<void> start();

  /// Stops watching and releases the observer thread. A no-op if not watching.
  Future<void> stop();

  /// Detected screenshots, in detection order (spec §3). Consumed by the push
  /// pipeline (#28) in the service isolate.
  Stream<ScreenshotEvent> get events;

  /// The observer's per-stage debug lines (spec §7: onChange, query ran). Fed
  /// into the in-app debug log so the ≤2s bar is measurable without new tooling.
  Stream<String> get diagnostics;
}

/// [ScreenshotWatcher] backed by the `imagesync/screenshot_observer` method
/// channel and the `imagesync/screenshot_events` event channel.
class ChannelScreenshotWatcher implements ScreenshotWatcher {
  ChannelScreenshotWatcher({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? defaultMethodChannel,
       _eventChannel = eventChannel ?? defaultEventChannel;

  static const defaultMethodChannel = MethodChannel(
    'imagesync/screenshot_observer',
  );
  static const defaultEventChannel = EventChannel(
    'imagesync/screenshot_events',
  );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  /// One native subscription, split into [events] and [diagnostics] below. The
  /// native side tags every emission with `type`: `"screenshot"` carries the
  /// §3 payload, `"log"` carries a §7 debug line.
  late final Stream<Map<Object?, Object?>> _raw = _eventChannel
      .receiveBroadcastStream()
      .cast<Map<Object?, Object?>>();

  @override
  Future<ScreenshotAccessLevel> accessLevel() async {
    final level = await _methodChannel.invokeMethod<String>('accessLevel');
    return ScreenshotAccessLevel.fromName(level);
  }

  @override
  Future<void> start() => _methodChannel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _methodChannel.invokeMethod<void>('stop');

  @override
  Stream<ScreenshotEvent> get events => _raw
      .where((event) => event['type'] == 'screenshot')
      .map(ScreenshotEvent.fromMap);

  @override
  Stream<String> get diagnostics => _raw
      .where((event) => event['type'] == 'log')
      .map((event) => event['message'] as String? ?? '');
}
