# Android platform constraints for seamless ImageSync

Research date: 2026-07-10. Target device: Xiaomi (MIUI/HyperOS), plus generic Android 13/14/15.
App shape today: Flutter app, `flutter_foreground_task` 9.2.2 foreground service (`dataSync` type,
`allowWakeLock`+`allowWifiLock` true) holding a WebSocket to a Bun/TS relay on the laptop.

All claims are traced to a primary source (official Android docs, AOSP, KDE Connect / Syncthing /
plugin source). Claims I could not pin to a primary source are marked **[UNVERIFIED]**. MIUI behavior
is inherently under-documented (Xiaomi ships no API/spec for its custom restrictions), so MIUI items
lean on vendor-agnostic docs plus community reports and are flagged as such.

---

## Q1 — Auto-detecting new screenshots with zero user action

**Verdict:** Feasible and this is the strongest zero-tap path. A `ContentObserver` on
`MediaStore.Images.Media.EXTERNAL_CONTENT_URI`, registered on the Android side inside the foreground
service, fires within ~1s of a new screenshot and lets you read the file — **provided the app holds
the FULL `READ_MEDIA_IMAGES` grant**. The Android 14 "Select photos" partial grant **breaks it**: new
screenshots are not in the user-selected set, so the observer's follow-up query returns nothing.
Android 14's `ScreenCaptureCallback` is **Activity-scoped and gives no image** — not usable from a
background service. On MIUI, budget for indexing delay and require autostart. In Flutter, use
`photo_manager`'s change-notify (it registers the observer natively) rather than the FFT isolate.

### ContentObserver is the real mechanism apps use
`photo_manager` registers a `ContentObserver` per media type against the MediaStore external URIs:

```
context.contentResolver.registerContentObserver(uri, true, mediaObserver)   // imageUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
```
Source: `flutter_photo_manager/.../core/PhotoManagerNotifyChannel.kt:43,50-52,30`. On `onChange`, it
queries `MediaStore` for `DATE_ADDED`/`DATE_MODIFIED` and classifies "insert" when the row is <30s old
(`PhotoManagerNotifyChannel.kt:150-160`). That is exactly the "new screenshot just landed" signal, and
it delivers the `id` so you can resolve the content URI and read bytes. Latency is MediaStore-indexing
bound, typically sub-second on stock once the scanner runs.

The `ScreenshotContentObserver` pattern (observe `EXTERNAL_CONTENT_URI`, check `DISPLAY_NAME`/relative
path contains "screenshot") is the same approach used by crash/feedback SDKs, e.g. Buglife's
`ScreenshotContentObserver.java` (github.com/Buglife/buglife-android). To distinguish a screenshot from
any new image, filter on `RELATIVE_PATH LIKE '%Screenshots%'` or `DISPLAY_NAME` containing "screenshot".

### Permissions on Android 13/14/15 — full vs. "Selected photos"
- Android 13+ replaced `READ_EXTERNAL_STORAGE` with `READ_MEDIA_IMAGES` for images.
- Android 14 added the **partial grant**: when the user picks "Select photos and videos", the app gets
  `READ_MEDIA_VISUAL_USER_SELECTED` and can **only** see the specific items the user selected —
  "the app can only access the specific photos and videos the user explicitly selected — it cannot see
  unselected photos." A brand-new screenshot is, by definition, not in that set.
  Source: developer.android.com/about/versions/14/changes/partial-photo-video-access.
- The MediaStore query API is identical for partial vs. full ("the same approach works whether the
  granted access is partial or full") — the **system silently filters** rows to the selected set. So
  your observer still fires on the URI notification, but the follow-up `query(... id ...)` returns an
  empty cursor for an unselected new screenshot, and you get nothing to read.
- **Consequence for ImageSync:** you must obtain the **full** `READ_MEDIA_IMAGES` grant. If the app
  targets SDK 34+ and declares `READ_MEDIA_VISUAL_USER_SELECTED`, the permission sheet offers the user
  "Select photos" — which is the wrong outcome here. `photo_manager`'s `PermissionDelegate34` requests
  `READ_MEDIA_VISUAL_USER_SELECTED` (photo_manager .../permission/impl/PermissionDelegate34.kt:21), so
  to force full access you either (a) do not declare `USER_SELECTED` and accept compatibility mode
  (temporary full grant that is revoked when backgrounded — bad for a persistent observer), or (b)
  request full access and guide the user to pick "Allow all". For a persistent background observer,
  **full "Allow all" is required**; partial/compat-mode access is revoked on backgrounding
  (same source: partial-photo-video-access, "compatibility mode" section).

### Android 14 ScreenCaptureCallback — not usable here (confirmed Activity-scoped)
`Activity.ScreenCaptureCallback` (permission `DETECT_SCREEN_CAPTURE`) "lets apps register callbacks on
a per-activity basis", registered in `onStart()`/unregistered in `onStop()`, and fires only "when the
user takes a screenshot **while that activity is visible**." It also "doesn't provide an image of the
actual screenshot." Source: developer.android.com/about/versions/14/features/screenshot-detection.
Because ImageSync has no visible activity when the user screenshots another app, and gets no image, this
API is irrelevant to background screenshot capture. Keep using the ContentObserver.

### Android 15 (and 16) screenshot/recording changes
Android 15 added a **screen-recording** detection callback, but it only detects apps using the
`MediaProjection` API and is about *your* app being recorded — not a general screenshot hook. Screenshots
via hardware buttons "cannot be detected via a screen recording callback but can be detected via a screen
capture callback on Android 14" (Activity-scoped, as above).
Sources: developer.android.com/about/versions/15/features; guardsquare.com/blog/android-15-screen-spying-protection.
Net: **no new background screenshot API in 15/16** that helps us; ContentObserver remains the path.

### MIUI/HyperOS quirks (community-sourced, **[UNVERIFIED]** against vendor docs)
- **DCIM/Screenshots location:** Xiaomi stores screenshots under `DCIM/Screenshots` (not the AOSP
  `Pictures/Screenshots`). Filter on the folder/`bucket_display_name` = "Screenshots" rather than a
  hard-coded path. Source: xiaomi.eu / itigic community threads (not authoritative).
- **Delayed MediaStore indexing:** MIUI's media scanner can lag, so the observer may fire seconds late
  or coalesce events. Treat the <30s "insert" window generously and de-dup by `id`.
- **Autostart / background restriction:** if the app is not whitelisted (autostart on, battery "No
  restrictions"), MIUI can freeze the process so the observer never runs. See Q4 checklist.

### Flutter wiring: where the observer must live
The observer **must be registered on the Android side against a `ContentResolver`**, on a thread with a
`Looper` (the `ContentObserver(Handler)` constructor needs one). `photo_manager` creates its observers
with `Handler(Looper.getMainLooper())` (PhotoManagerPlugin.kt:84-88, PhotoManagerNotifyChannel.kt:93-96),
i.e. it hangs off the **main UI-thread Looper of whatever engine registered it**.

Caveat with the FFT isolate: `flutter_foreground_task` spins up a **second `FlutterEngine`** inside the
service (`ForegroundTask.kt:47-49`, `FlutterEngine(context)` + `executeDartCallback`). Plugins are not
auto-registered in that engine unless FFT's plugin-registration path runs, and any `Handler(Looper.getMainLooper())`
created there still binds to the app main looper (which exists process-wide), so callbacks are delivered
regardless of isolate — but the Dart `MethodChannel` receiving them lives on whichever engine registered
the plugin. Practical guidance:
  - **Recommended:** register the ContentObserver from a **small dedicated platform channel / native
    piece owned by the foreground service** (or ensure `photo_manager` is registered in the same engine
    the service uses), so the observer's lifetime matches the service, not a transient UI activity.
  - The observer survives as long as its owning `ContentResolver`/process is alive and the `Handler`
    thread's Looper is running. It does **not** need the UI activity; it does need the process kept
    alive (Q4).
  - Existing packages: `photo_manager` (change-notify via ContentObserver, shown above) is the
    lowest-effort. `media_store_plus` focuses on writes, not change notifications. A ~40-line platform
    channel registering a `ContentObserver` in the service is the most robust if you want it tied to the
    FFT service lifecycle exactly.

---

## Q2 — Background clipboard READ workarounds post-Android 10

**Verdict:** The baseline is real and enforced in AOSP: **only the focused app or the default IME can
read the clipboard.** For a sideloaded personal app the realistic zero-tap text-read options are, in
order: **(a) the KDE Connect READ_LOGS + invisible-activity trick** (still shipped, still works via a
one-time ADB grant, but fragile), or **(c) an AccessibilityService** (can read text of focused/edited
fields but not arbitrary clipboard; heavier). Becoming the default IME (b) is not realistic for this
user. Given screenshots are the main payload, prioritize Q1; for **text**, the honest answer is there is
no fully stock, zero-ADB, zero-tap background clipboard read on Android 13/14/15.

### Baseline confirmed in AOSP
`ClipboardService.clipboardAccessAllowed()` for `OP_READ_CLIPBOARD` allows access only if one of:
`READ_CLIPBOARD_IN_BACKGROUND` permission (signature/privileged — not grantable to a normal app), the
caller **is the default IME** (`isDefaultIme`), the caller's UID **is focused**
(`isDefaultDeviceAndUidFocused` / virtual-device focus), is a system window with focus, or is the
ContentCapture/Autofill/VirtualDevice service.
Source: `platform_frameworks_base` services/core/.../clipboard/ClipboardService.java (android-15.0.0_r1):
- read branch: lines 1345-1379 (`case OP_READ_CLIPBOARD`), gated by `isDefaultIme` (1341, 1418-1429)
  and `isDefaultDeviceAndUidFocused` (1352, 1405-1407);
- the `READ_CLIPBOARD_IN_BACKGROUND` escape hatch: lines 1336-1338 ("Shell can access the clipboard for
  testing purposes").
A background foreground service is **not focused**, so it fails all read branches. Denial is logged as
"Denying clipboard access to <pkg>, application is not in focus nor is it a system service" (1388-1392).

### (a) READ_LOGS + logcat watch + invisible floating activity — KDE Connect's shipped trick
This still exists in current KDE Connect Android master (2025/2026) and works. Mechanism:
1. `ClipboardListener` (Kotlin) runs, on Android Q+ *only if* `READ_LOGS` is granted, a background
   `logcat` process filtered to `ClipboardService` error lines:
   ```
   Runtime.getRuntime().exec(arrayOf("logcat","-T",timeStamp,logcatFilter,"*:S"))   // logcatFilter = "E ClipboardService" (>VanillaIceCream) else "ClipboardService:E"
   ```
   Source: `kdeconnect-android` .../plugins/clipboard/ClipboardListener.kt:46-59.
2. When it sees a denied-access log line containing its own package id, it launches a transparent,
   no-touch `ClipboardFloatingActivity` that momentarily takes focus, reads the clipboard in
   `onWindowFocusChanged(hasFocus)`, then `finish()`es — the header comment says it is "invisible and
   doesn't require any interaction from the user."
   Source: `.../clipboard/ClipboardFloatingActivity.java:20-39,51-62`.
3. Enablement gate: `ClipboardPlugin.canSyncAutomatically()` returns true on <Q, else requires
   `READ_LOGS` granted (`ClipboardPlugin.kt:154-160`).
4. Required ADB one-time setup (documented in the source header, ClipboardFloatingActivity.java:29-36):
   ```
   adb -d shell pm grant org.kde.kdeconnect_tp android.permission.READ_LOGS
   adb -d shell appops set org.kde.kdeconnect_tp SYSTEM_ALERT_WINDOW allow   # "draw over other apps", optional but more reliable
   adb -d shell am force-stop org.kde.kdeconnect_tp
   ```
The KDE MR that introduced it is invent.kde.org/network/kdeconnect-android `!150`
("Add logs reading for sending clipboard on Android 10").
**Status Android 13/14/15:** the code path is still present and updated (note the `VANILLA_ICE_CREAM`
= Android 15 branch at ClipboardListener.kt:51), i.e. KDE actively maintains it for current releases.
Caveats: `READ_LOGS` can only be granted via ADB (not a normal runtime permission); on some OEMs the
granted READ_LOGS still doesn't expose other apps' logs, and background-activity-start limits (Android
10+ "start activity from background" restrictions) can block the invisible-activity launch — the
`SYSTEM_ALERT_WINDOW` appop is what makes it reliable. This is exactly ImageSync's scenario, so it is
viable if the user is willing to run the ADB grant once. **Marginal on MIUI [UNVERIFIED]:** background
activity starts and draw-over-other-apps are additionally gated by MIUI toggles.

### (b) Default IME — confirmed viable but unrealistic
`isDefaultIme()` is an unconditional allow for reads (ClipboardService.java:1341, 1418-1429). But the
user would have to switch their keyboard to ImageSync's IME, which is a non-starter for a clipboard-sync
utility. Confirmed as the "clean" API path, rejected on UX.

### (c) AccessibilityService
An AccessibilityService can observe `TYPE_VIEW_TEXT_SELECTION_CHANGED` / text of the focused node and
can read `AccessibilityNodeInfo` text, and can itself call clipboard actions on nodes
(`ACTION_COPY`/`ACTION_PASTE`). It does **not** get a general "clipboard changed" hook and cannot read
arbitrary clipboard contents app-wide — it sees what's on screen / in focused editable fields. It is a
heavyweight always-on service with a scary permission prompt. Play-policy restrictions on Accessibility
are **irrelevant here** (sideloaded personal app, not distributed), so it's *allowed*, just not a clean
fit for "read whatever the user copied anywhere". Treat as a fallback, not primary.
(Behavioral summary from AccessibilityService API docs; no single quotable line for "cannot read
clipboard globally" — this is the absence of any such API. **[Partially UNVERIFIED]**.)

### (d) Share-sheet baseline
The existing "share to ImageSync" path is the only 100%-stock, no-ADB, no-special-permission way to get
arbitrary content (text or image) out of another app — but it costs the user a tap/share action. It's the
correct universal fallback.

### What KDE Connect actually ships for phone→desktop clipboard today
- Automatic send-on-copy on Android 10+ **only** when the READ_LOGS hack is enabled
  (`ClipboardPlugin.getUiButtons/getUiMenuEntries` demote the manual "Send clipboard" action to a menu
  entry when `canSyncAutomatically` is true, and show a prominent button otherwise —
  ClipboardPlugin.kt:91-110).
- Otherwise a **manual** "Send clipboard" button (foreground notification action / quick-settings tile)
  that opens the same invisible activity: `ClipboardTileService.kt`, `ClipboardFloatingActivity`.
- On the wire: packet types `kdeconnect.clipboard` (content only) and `kdeconnect.clipboard.connect`
  (content + timestamp, sent on connect, last-writer-wins via timestamp compare) —
  ClipboardPlugin.kt:32-74, 135-152.
- Bug tracking the "no auto-send if the persistent notification is disabled" limitation:
  bugs.kde.org/show_bug.cgi?id=446366.

**Realistic verdict for ImageSync text:** without the one-time ADB `READ_LOGS` grant, background
auto-read of copied text is **not** possible on 13/14/15 (AOSP-enforced). With it, KDE's exact recipe
works and is maintained. Otherwise fall back to a manual "send clipboard" tile/notification action or the
share sheet. Screenshots (Q1) do not have this limitation and should carry the "zero-tap" story.

---

## Q3 — Background clipboard WRITE (laptop -> phone)

**Verdict:** On **stock** Android 13/14/15, a background foreground service **can** call
`setPrimaryClip()` — writing does not require focus. On **MIUI/HyperOS**, background clipboard writes are
frequently blocked by Xiaomi's privacy layer (SecurityException / silent no-op) unless the app is
whitelisted via MIUI's per-app permission toggles. So laptop->phone can be truly zero-tap on stock and
*when the screen is on*, and on MIUI it's zero-tap only after the user flips the right MIUI toggles.

### AOSP: writing is allowed without focus
In `clipboardAccessAllowed`, the write branch is unconditional:
```
case AppOpsManager.OP_WRITE_CLIPBOARD:
    // Writing is allowed without focus.
    allowed = true;
    break;
```
Source: `ClipboardService.java:1381-1384` (android-15.0.0_r1). `setPrimaryClip` calls
`clipboardAccessAllowed(OP_WRITE_CLIPBOARD, ...)` at lines 589-590. The only remaining gate is the app-op
`noteOp(OP_WRITE_CLIPBOARD, ...)` at 1396-1402, which is `MODE_ALLOWED` by default for normal apps. So
on AOSP/stock, a foreground service writing the clipboard succeeds even with no visible activity.
Note: no "pasted from clipboard" toast fires on **write** — the Android 12+ toast is only on
`getPrimaryClip()` reads (developer.android.com/about/versions/12/behavior-changes-all, clipboard
section). So a background write is silent and non-intrusive.

### MIUI/HyperOS blocks (community-sourced, **[UNVERIFIED]** vs. vendor docs)
- Flutter issue flutter/flutter#102300 documents `setPrimaryClip` throwing SecurityException
  ("Package ... does not belong to <uid>") on multiple MIUI 13 devices — MIUI's security layer
  intercepting clipboard writes.
- MIUI exposes a per-app "Clipboard" permission and a "Modify system settings" toggle; community reports
  say enabling the app's clipboard permission (Settings > Apps > ImageSync > Permissions) and setting
  background/autostart to allowed is what unblocks background writes. xiaomiui.net/the-meaning-of-all-miui-permissions
  catalogs these but there is no official spec.
- Because this is device-specific and undocumented, ImageSync should: attempt `setPrimaryClip`, catch
  `SecurityException`, and if it fails, surface a one-time "grant Clipboard permission in MIUI settings"
  hint. Consider also showing the received content in the notification so the user can copy it manually
  as a fallback.

### Zero-tap receive verdict
- Stock 13/14/15: **yes, zero-tap**, screen on or off (write path has no focus/screen gate in AOSP).
- MIUI/HyperOS: **yes after the user enables the app's MIUI Clipboard permission + autostart**; before
  that, expect silent failure or SecurityException. Screen-on improves reliability but AOSP itself has no
  screen-on requirement for writes.

---

## Q4 — Persistent WebSocket survival on MIUI/HyperOS

**Verdict:** The reconnect-every-2-5-min pattern is almost certainly **light-Doze network suspension**
plus the **absence of a client-side application-level keepalive**. AOSP light-idle defaults are
"60s inactive -> enter light idle -> 300s idle window", which matches your 2-5 min cadence exactly. A
foreground service does **not** exempt you from Doze; only the **battery-optimization whitelist** grants
network + wake-lock during Doze. `flutter_foreground_task` acquires a `PARTIAL_WAKE_LOCK` and a
(deprecated) `WIFI_MODE_FULL_HIGH_PERF` Wi-Fi lock that Android now downgrades to
`WIFI_MODE_FULL_LOW_LATENCY` — which is only active while the screen is on and the app is foreground,
so it does little for an idle-screen socket. Your relay pings every 30s but the **phone sends no pings**,
so a middlebox/Doze-suspended socket looks alive to the phone until the OS tears it down. Verdict:
reconnect-if-cheap is acceptable, and largely eliminable with (1) app battery-opt exemption + MIUI
autostart, and (2) a phone-side application ping every ~30s.

### The timing matches AOSP light Doze
Light Doze defaults (AOSP): `device_idle_light_after_inactive_to_ms = 60000` (enter light idle 60s after
screen off/inactive) and `device_idle_light_idle_to_ms = 300000` (5-minute light-idle window).
Source: `platform_frameworks_base` core/res/res/values/config_device_idle.xml:30-34 (android-15.0.0_r1),
consumed by `DeviceIdleController.java` (constants around lines 1089, 1458-1472). During Doze the system
"suspends network access" and "ignores wake locks", lifting them only during periodic maintenance
windows. Source: developer.android.com/training/monitoring-device-state/doze-standby.
=> A socket that's fine while the screen is on starts getting its network cut ~1 min after the screen
goes off, and the maintenance-window cadence (minutes, widening over time) lines up with "reconnected 3
times over ~10 min, every 2-5 min."

### A foreground service does NOT exempt you from Doze
The Doze doc explicitly warns: "Only use a foreground service for tasks the user expects... **Don't start
a foreground service just to prevent the system from determining that your app is idle.**" A process
"in the foreground... as an activity or foreground service" avoids **App Standby**, but Doze restrictions
(network suspend, wake-lock ignore) still apply device-wide. The exemption that actually restores network
+ wake locks during Doze is the **battery-optimization whitelist**: "An app that is partially exempt can
use the network and hold partial wake locks during Doze and App Standby."
Source: developer.android.com/training/monitoring-device-state/doze-standby.
**Action:** request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (or send the user to the exemption setting).
This is the single highest-impact fix on stock Android.

### What flutter_foreground_task actually acquires (checked in source)
- Wake lock: `PowerManager.PARTIAL_WAKE_LOCK`, tag `ForegroundService:WakeLock`, only when
  `allowWakeLock` is true. Source: `flutter_foreground_task` .../service/ForegroundService.kt:428-431.
- Wi-Fi lock: `WifiManager.WIFI_MODE_FULL_HIGH_PERF`, tag `ForegroundService:WifiLock`, only when
  `allowWifiLock` is true. Source: ForegroundService.kt:438-441.
- **Important:** `WIFI_MODE_FULL_HIGH_PERF` is **deprecated and auto-replaced with
  `WIFI_MODE_FULL_LOW_LATENCY`** by the framework: "any request to the WIFI_MODE_FULL_HIGH_PERF will now
  obtain a WIFI_MODE_FULL_LOW_LATENCY lock instead." And LOW_LATENCY "is only active when the screen is
  on" and "when the acquiring app is running in the foreground."
  Source: AOSP `WifiManager.java` (packages/modules/Wifi, main): WIFI_MODE_FULL_HIGH_PERF javadoc
  lines ~1874-1884, WIFI_MODE_FULL_LOW_LATENCY conditions lines 1886-1914.
  => The FFT Wi-Fi lock gives you **nothing while the screen is off**, which is exactly when your socket
  dies. The PARTIAL_WAKE_LOCK keeps the CPU on but does not restore Doze-suspended network. This confirms
  the wake/wifi locks alone won't keep an idle-screen socket alive without the battery-opt exemption.

### Your relay pings; your phone does not
Relay side sends WebSocket pings every 30s and reaps a socket silent past 90s:
`src/relay/relay.ts:15-16` (`defaultHeartbeatIntervalMs = 30_000`, `defaultStaleAfterMs = 90_000`),
`:45-55` (`setInterval(... socket.ping() ...)`). But the Flutter client
(`app/lib/src/shared/relay_connection.dart`) has **no timer and sends no ping/keepalive** — it only
reacts to inbound messages (`start()` just listens; there is no periodic send). So from the phone's TCP
stack the connection is idle outbound, and NAT/middlebox/Doze can drop it without the phone noticing
until the next OS event. Adding a phone-side app-level ping is the second high-impact fix.

### What mature apps do
- **KDE Connect (Android):** enables TCP keepalive on the socket (`socket.setKeepAlive(true)` —
  `LanLinkProvider.java:266-271`) and uses a 10s socket read timeout (`LanLink.java:200`,
  `SslHelper.kt:176`). It runs a `connectedDevice` foreground service
  (`BackgroundService.kt:244`, manifest `foregroundServiceType="connectedDevice"`,
  `FOREGROUND_SERVICE_CONNECTED_DEVICE`) and holds `WAKE_LOCK`. It relies on TCP-level keepalive plus
  reconnect-on-drop rather than fighting Doze, and it ships explicit dontkillmyapp-style guidance.
- **Syncthing-android:** holds a `PowerManager.PARTIAL_WAKE_LOCK` while the binary runs
  (`SyncthingRunnable.java:127-132`, gated by a user "wakelock while running" pref, Constants.java:35).
  The Syncthing protocol (BEP v1) sends a **Ping every 90 seconds** if no other message was sent in the
  preceding 90s. Source: docs.syncthing.net/specs/bep-v1.html ("A Ping message is sent every 90 seconds,
  if no other message has been sent in the preceding 90 seconds."). So ~30-90s is the mature-app
  app-level keepalive range; your 30s relay ping is in range, but it must be **bidirectional**.
- **dontkillmyapp.com Xiaomi checklist** (the standard MIUI survival steps): enable **Autostart**
  (Security > Permissions > Auto-start, and on MIUI 14 Settings > Apps > <app> > App permissions >
  **Background autostart**); set the app's **battery saver to "No restrictions"** (Security > Battery >
  App Battery Saver); set "Saving power in the background" to No restrictions; turn off **MIUI
  optimization** (Developer options) if needed; and **lock the app in recents** (pull the card down to
  pin). Source: dontkillmyapp.com/xiaomi.

### Practical verdict on connection stability
- Reconnect-every-few-minutes is **acceptable if cheap** — your relay already reaps stale sockets at 90s
  and the client reconnects; each reconnect re-auths quickly. If payloads are small and reconnect is
  fast, the current behavior loses at most a few minutes of "instant" delivery when idle.
- It is **largely eliminable** by: (1) getting the app onto the **battery-optimization whitelist**
  (stock) and MIUI **autostart + "No restrictions" + lock-in-recents** (this is the dominant factor on
  MIUI); (2) adding a **phone-side application ping every ~30s** (mirror the relay) so the socket stays
  warm and both sides detect death fast; (3) accepting that `WIFI_MODE_FULL_LOW_LATENCY` does nothing
  screen-off — the wake-lock + battery exemption is what carries screen-off survival. Even fully tuned,
  MIUI may still occasionally drop the socket; keep the fast-reconnect + relay-side reaping you already
  have as the safety net.

---

## Architecture implications for ImageSync

| Goal | Feasible? | How | Main caveat |
|---|---|---|---|
| **Zero-tap screenshot push (phone -> laptop)** | **Yes** | Native `ContentObserver` on `MediaStore.Images` in the foreground service; filter to Screenshots bucket; read bytes on insert; publish over the existing socket. Reuse `photo_manager` change-notify or a ~40-line platform channel. | Needs **full** `READ_MEDIA_IMAGES` ("Allow all"); the Android 14 partial grant silently hides new screenshots. Keep the app process alive (Q4). MIUI: DCIM/Screenshots path + indexing lag. |
| **Zero-tap text push (phone -> laptop)** | **Only with one-time ADB** | Adopt KDE Connect's `READ_LOGS` + logcat-watch + invisible `ClipboardFloatingActivity` recipe (verified still shipped for A15). | AOSP forbids background clipboard reads; without the ADB `READ_LOGS` grant this is impossible. Fallbacks: manual "send clipboard" tile / share sheet. MIUI adds background-activity-start friction. |
| **Zero-tap receive -> phone clipboard (laptop -> phone)** | **Yes on stock; conditional on MIUI** | Foreground service calls `setPrimaryClip()`; AOSP allows writes without focus and shows no toast. | MIUI may block with SecurityException until the user enables the app's MIUI Clipboard permission + autostart. Catch and guide; show content in notification as fallback. |
| **Connection stability** | **Good, largely eliminable churn** | Battery-opt exemption (stock) + MIUI autostart/"No restrictions"/lock-in-recents; add a **phone-side ~30s app ping** to mirror the relay; enable TCP keepalive on the socket. | FFT's Wi-Fi lock is screen-on/foreground-only (deprecated HIGH_PERF -> LOW_LATENCY); a foreground service alone does NOT beat Doze — the battery whitelist does. Expect occasional MIUI drops regardless; keep fast reconnect. |

### Concrete recommended changes (not implemented here — research only)
1. Add a native `ContentObserver` on `MediaStore.Images.Media.EXTERNAL_CONTENT_URI` owned by the FFT
   service; request **full** `READ_MEDIA_IMAGES` (guide user to "Allow all", do not lean on partial).
2. Add a phone-side keepalive: a periodic ~30s ping from `RelayConnection`/transport to mirror the relay
   heartbeat, so both ends stay warm and detect drops fast. `relay_connection.dart` currently sends none.
3. On first run, request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` and, on MIUI, deep-link the user to
   Autostart + Battery "No restrictions"; document the "lock app in recents" step.
4. For laptop->phone, wrap `setPrimaryClip` in try/catch(SecurityException) with a MIUI-permission hint;
   always mirror the received content into the notification as a manual fallback.
5. For text phone->laptop, offer the KDE-style READ_LOGS auto-mode as an *opt-in advanced* feature with a
   copy-paste ADB command, defaulting to a manual "send clipboard" action + share sheet.

### Primary sources
- AOSP `ClipboardService.java` (android-15.0.0_r1): clipboardAccessAllowed read/write branches
  (lines 1315-1403), setPrimaryClip write gate (589-590), read gate call sites (663-831).
- AOSP `WifiManager.java` (packages/modules/Wifi, main): WIFI_MODE_FULL_HIGH_PERF deprecation ->
  LOW_LATENCY, LOW_LATENCY screen-on/foreground conditions (javadoc ~1855-1914).
- AOSP `config_device_idle.xml` (android-15.0.0_r1): light-idle 60s/300s defaults (lines 30-34);
  `DeviceIdleController.java` constants.
- developer.android.com: partial-photo-video-access; versions/14/features/screenshot-detection;
  versions/15/features; training/monitoring-device-state/doze-standby; versions/12/behavior-changes-all.
- KDE Connect Android (master): plugins/clipboard/{ClipboardListener.kt, ClipboardPlugin.kt,
  ClipboardFloatingActivity.java, ClipboardTileService.kt}; backends/lan/{LanLinkProvider.java,
  LanLink.java}; BackgroundService.kt; helpers/security/SslHelper.kt; AndroidManifest.xml; MR !150;
  bug 446366.
- Syncthing-android: service/SyncthingRunnable.java (wakelock), Constants.java; docs.syncthing.net BEP v1
  (90s ping).
- flutter_foreground_task (master): service/{ForegroundService.kt (locks), ForegroundTask.kt (engine)}.
- flutter_photo_manager (master): core/PhotoManagerNotifyChannel.kt, core/PhotoManagerPlugin.kt,
  permission/impl/PermissionDelegate34.kt.
- dontkillmyapp.com/xiaomi (MIUI checklist).
- ImageSync repo: src/relay/relay.ts (heartbeat 30s/stale 90s), app/lib/src/shared/relay_connection.dart
  (no client ping), app manifest (dataSync FGS, WAKE_LOCK).
