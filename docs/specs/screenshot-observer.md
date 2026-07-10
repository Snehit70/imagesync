# Spec: Screenshot observer — MediaStore ContentObserver in the foreground service

Status: locked (resolves [#27](https://github.com/Snehit70/imagesync/issues/27)).
Research basis: `docs/research/android-seamless-sync.md` Q1.
Scope boundary: this spec ends at a **screenshot event delivered to the service isolate's Dart
side**. Reading bytes, encrypting, and publishing is the pipeline spec
([#28](https://github.com/Snehit70/imagesync/issues/28)). Permission *UX* (screens, copy, when to
prompt) is the onboarding spec ([#30](https://github.com/Snehit70/imagesync/issues/30)); this spec
defines the grant states and detection logic that flow consumes.

## 1. Mechanism and ownership

**Decision: a small app-local Flutter plugin, not `photo_manager`.**

- New local plugin package `app/packages/screenshot_observer/` (path dependency in
  `app/pubspec.yaml`). Being a real plugin (a class implementing `FlutterPlugin`) puts it in
  `GeneratedPluginRegistrant`, so Flutter's automatic plugin registration wires it into **every**
  engine — including the second `FlutterEngine` that `flutter_foreground_task` spins up for the
  service isolate. This is the whole reason it is a plugin rather than another
  `MainActivity.configureFlutterEngine` channel: those are Activity-engine-only
  (see `MainActivity.kt`), and the observer must be reachable from the service isolate.
- `photo_manager` is rejected: it drags in a large dependency for one observer, its
  `PermissionDelegate34` requests `READ_MEDIA_VISUAL_USER_SELECTED` (the partial grant we must
  avoid, §5), and its observer lifetime follows whichever engine registered it rather than the
  service. The plugin is ~40 lines of Kotlin plus channel glue, per the research recommendation.

**Native side (Kotlin, single file `ScreenshotObserverPlugin.kt`):**

- The observing state (`ContentObserver`, `HandlerThread`, seen-id set) lives in a **process-wide
  singleton** (`object ScreenshotWatcher`), not in the plugin instance. Both engines get a plugin
  instance; the singleton guarantees at most one registered observer no matter which engines attach
  or how often the service restarts. `start` is idempotent; `stop` is a no-op if not watching.
- Registration:
  `contentResolver.registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, /*notifyForDescendants=*/true, observer)`
  using the **application context** resolver, so lifetime is the process, controlled explicitly by
  start/stop from the service.

## 2. Threading: Looper/Handler placement

**Decision: a dedicated `HandlerThread`, not the main looper.**

- `start` creates and starts `HandlerThread("imagesync-screenshot-observer")`; the
  `ContentObserver(Handler(thread.looper))` receives `onChange` on that thread, and the follow-up
  MediaStore query runs there too — never on the main thread (the service process also renders UI
  when the activity is open; queries during MIUI indexing bursts must not jank it).
- `stop` unregisters the observer and quits the thread (`quitSafely`).
- Event delivery to Dart hops back to the main thread
  (`Handler(Looper.getMainLooper()).post { sink.success(...) }`) because platform-channel messages
  must be sent from the platform thread.
- FFT's second-engine caveat from the research (main-looper handlers bind process-wide, but the
  receiving `MethodChannel` lives on whichever engine registered it) is neutralized by the
  singleton + auto-registration design: the channel exists on both engines, and only the service
  isolate subscribes (§6).

## 3. Channel contract

Two channels, names namespaced like the existing ones:

- `MethodChannel imagesync/screenshot_observer`
  - `start()` — begin watching. Errors with `no-permission` if the full grant (§5) is absent.
  - `stop()` — stop watching, release the thread.
  - `accessLevel()` — returns `"full" | "partial" | "denied"` (§5 detection).
- `EventChannel imagesync/screenshot_events` — stream of screenshot events:

```json
{
  "id": 12345,
  "uri": "content://media/external/images/media/12345",
  "displayName": "Screenshot_2026-07-10-14-03-22-123_com.foo.png",
  "mimeType": "image/png",
  "sizeBytes": 482133,
  "dateAddedEpochSeconds": 1783608202,
  "detectedAtEpochMillis": 1783608202412
}
```

`uri` is `ContentUris.withAppendedId(EXTERNAL_CONTENT_URI, id)` — the handle #28 uses to open the
bytes. `detectedAtEpochMillis` minus screenshot capture time is the observer-latency half of the
map's ≤2s success bar (§7).

## 4. `onChange` → query: classification, dedup, coalescing

MIUI coalesces observer events and its media scanner can lag; a single screenshot can also fire
multiple `onChange` calls (pending row insert, then `IS_PENDING` 0 flip). The pipeline:

1. **Debounce:** each `onChange` (re)arms a **500ms** timer on the observer thread; the query runs
   when it fires. A burst of notifications produces one query.
2. **Query** (default query args — on API 29+ these exclude `IS_PENDING=1` rows, so a row only
   becomes visible once the file is fully written; the pending→final flip is what we catch):
   - projection: `_ID`, `DISPLAY_NAME`, `BUCKET_DISPLAY_NAME`, `RELATIVE_PATH`, `MIME_TYPE`,
     `SIZE`, `DATE_ADDED`
   - selection: `DATE_ADDED >= :windowStart` where `windowStart = now − 30s` — the generous
     insert window from the research (`PhotoManagerNotifyChannel` uses <30s; MIUI indexing lag
     makes a tight window drop events)
   - sort: `DATE_ADDED DESC`, iterate all rows in the window (a burst can land several
     screenshots).
3. **Insert classification:** a row is a *new* screenshot iff its `_ID` is not in the seen set
   **and** `DATE_ADDED >= startWatermark`. The watermark is set to *now* at `start()` so a service
   restart never replays a screenshot taken before the service came up; there is no catch-up scan
   on start (missed-while-dead screenshots are explicitly not auto-pushed — the share sheet covers
   them).
4. **Dedup:** bounded LRU set of the last **64** emitted `_ID`s, in-memory in the singleton. Ids
   are stable per MediaStore row, so the pending-flip second event and coalesced re-queries dedup
   cleanly. The set intentionally does not persist: the watermark already guards restarts.
5. **Screenshot filter** (§4a) → emit event per surviving row.

### 4a. Screenshot filtering that works on MIUI

**Decision: filter on bucket name, with a display-name fallback — never on a hard-coded path.**

A row is a screenshot iff:

- `BUCKET_DISPLAY_NAME` equals `"Screenshots"` case-insensitively — matches AOSP
  `Pictures/Screenshots` and MIUI/HyperOS `DCIM/Screenshots` alike, because the bucket name is the
  leaf folder name regardless of parent; **or**
- `DISPLAY_NAME` contains `"screenshot"` case-insensitively — fallback for OEM skins that localize
  the folder but keep the stock `Screenshot_*.png` naming (Buglife's `ScreenshotContentObserver`
  pattern).

Rows failing both are dropped silently (they are camera shots, downloads, app-saved images — all
manual-share territory by the map's locked product decision). `RELATIVE_PATH` is carried in the
projection for debug logging only, not filtering.

## 5. Permissions: full `READ_MEDIA_IMAGES`, partial-grant detection

**Manifest** (`app/android/app/src/main/AndroidManifest.xml`) adds:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
                 android:maxSdkVersion="32" />
```

**`READ_MEDIA_VISUAL_USER_SELECTED` is deliberately NOT declared.** Declaring it opts the app into
the Android 14+ "Select photos" partial-grant flow as a first-class outcome. Not declaring it
means: if the user still picks "Select photos" on the system sheet, the app runs in compatibility
mode (a transient full grant revoked when the app leaves the foreground) — useless for a
persistent observer, and detectable as *partial* below. Only the full "Allow all" grant sustains
the observer.

**Why full is mandatory (Android 14+):** with a partial grant the system still fires `onChange`
notifications, but silently filters query results to the user-selected set — a brand-new
screenshot is never in that set, so the follow-up query returns an empty cursor and detection
silently produces nothing. There is no error to catch; it must be prevented at the grant level.

**Detection (`accessLevel()`):**

| Result | Condition |
|---|---|
| `full` | `checkSelfPermission(READ_MEDIA_IMAGES) == GRANTED` (pre-33: `READ_EXTERNAL_STORAGE`) |
| `partial` | API 34+, `READ_MEDIA_IMAGES` denied, `checkSelfPermission(READ_MEDIA_VISUAL_USER_SELECTED) == GRANTED` (the system grants it on "Select photos" even though we don't declare it) |
| `denied` | everything else |

**Handling contract** (consumed by #30 for UX):

- `start()` refuses unless `full`, returning `no-permission` with the detected level as detail.
- On `partial` or `denied` while the auto-push setting is on, the service surfaces a persistent
  "auto-push paused — allow all photos" state (notification text + in-app), deep-linking to the
  app's system settings page (`ACTION_APPLICATION_DETAILS_SETTINGS`) — after a partial choice the
  runtime-permission dialog can no longer offer "Allow all", so settings is the only recovery
  path.
- `accessLevel()` is re-checked every service start and every return-to-foreground of the app,
  since the user can downgrade the grant in settings at any time; a downgrade while watching stops
  the observer and enters the paused state.

## 6. Service lifecycle wiring (Dart)

- The service isolate owns the subscription. `ServiceRelayController` gains an optional
  screenshot-watcher collaborator (injected like `connectionFactory`, keeping the class testable):
  - `_sync()` (which already loads settings) starts the watcher when the auto-push setting is on
    and access is `full`; stops it when the setting is off. The map's locked decision — always-on
    while the service runs, settings toggle to pause — maps to: toggle flips → UI sends the
    existing `serviceSyncCommand` → `_sync()` reconciles watcher state alongside the connection.
  - `stop()` (service `onDestroy`) stops the watcher and quits the handler thread.
- Observer events are handed to the push pipeline (#28) inside the service isolate; nothing is
  forwarded to the UI isolate except debug-log lines via the existing `emit({'kind': 'log', ...})`
  channel.
- The UI isolate never calls `start()`; it may call `accessLevel()` for onboarding/settings
  display (the plugin is registered in its engine too, and `accessLevel` touches no observer
  state).

## 7. Instrumentation for the success bar

Each stage logs through the existing debug log so the ≤2s screen-on target is measurable without
new tooling:

- `onChange` received (timestamp, uri if provided)
- query ran (window start, rows in window, rows surviving filter)
- event emitted (`id`, `displayName`, `detectedAtEpochMillis`)

Detection latency = `detectedAtEpochMillis` − file's `DATE_ADDED`×1000 (coarse, DATE_ADDED is
seconds) — good enough to attribute delay to MIUI indexing vs. our debounce. End-to-end
measurement (screenshot → laptop clipboard) is defined in the pipeline spec (#28).

## 8. Known limits (accepted)

- Screenshots taken while the service is dead are never auto-pushed (watermark, no catch-up scan);
  the share sheet is the documented fallback.
- If MIUI freezes the process (no autostart / battery restrictions), the observer silently stops
  with it — survival setup is [#26](https://github.com/Snehit70/imagesync/issues/26)'s territory.
- MIUI indexing lag can push detection past 2s occasionally; the map's success bar is measured
  screen-on on a set-up device, and the 30s window ensures late-indexed rows are still caught.
- OEMs whose screenshot folder is neither named "Screenshots" nor names files `Screenshot_*` will
  be missed. Target devices (MIUI/HyperOS + stock) both pass; no further generalization.
