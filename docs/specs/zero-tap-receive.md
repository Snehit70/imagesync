# Zero-tap receive: silent clipboard write with quiet receipt

Spec for Seamless Sync ticket [#29](https://github.com/Snehit70/imagesync/issues/29).
Research basis: [`docs/research/android-seamless-sync.md`](../research/android-seamless-sync.md) Q3.

**Goal:** a payload arriving from the laptop lands in the phone clipboard with zero taps
while the service runs, with a quiet receipt notification whose tap remains the
guaranteed copy fallback (the MIUI-blocked path).

## Current state and why zero-tap doesn't work today

The service isolate (`ImageSyncForegroundTaskHandler` → `ServiceRelayController` →
`PayloadReceiver`) already attempts a best-effort clipboard write on every received
frame — but **both attempts structurally fail in the service isolate**, independent of
MIUI:

- **Text** goes through Flutter's `Clipboard.setData` (`SystemChannels.platform`). The
  Android-side handler (`PlatformPlugin`) is only attached to a `FlutterEngine` when an
  Activity attaches to it. The foreground task's engine is headless, so the call fails
  with `MissingPluginException` every time.
- **Image** goes through the `imagesync/clipboard` MethodChannel, which is registered
  only in `MainActivity.configureFlutterEngine` — the activity engine. The service
  engine has no handler; `MissingPluginException` again (already noted in a comment in
  `payload_receiver.dart`).

Both failures are swallowed by the try/catch, so today the high-priority "tap to copy"
notification is the *only* working receive path. AOSP itself permits the write: the
`OP_WRITE_CLIPBOARD` branch of `clipboardAccessAllowed` is unconditionally allowed
without focus, and no toast fires on writes (research Q3, `ClipboardService.java`
android-15.0.0_r1). The gap is purely our channel wiring.

## Decisions

### D1 — Native clipboard access becomes a local Flutter plugin

Move clipboard writing out of `MainActivity` into a local plugin package (path
dependency, e.g. `app/plugins/imagesync_clipboard/`) whose Kotlin class implements
`FlutterPlugin` and registers the `imagesync/clipboard` MethodChannel using the
**application context**.

Why a plugin package rather than a channel in `MainActivity` or an `Application`
subclass: plugins listed in the pubspec land in `GeneratedPluginRegistrant`, and
`flutter_foreground_task` (v9.x, in use) constructs the task's `FlutterEngine` with
automatic plugin registration — so the channel attaches to **both** the activity engine
and the headless service engine with no per-engine wiring. `ClipboardManager`,
`FileProvider.getUriForFile`, and `setPrimaryClip` all work from application context;
no Activity is required (research Q3).

Channel methods:

- `writeText(text)` — builds `ClipData.newPlainText` and calls `setPrimaryClip`.
- `writeImage(path, mime)` — existing behavior moved verbatim: FileProvider content
  URI over the `imagesync_received/` subtree, `ClipData` with the mime, `setPrimaryClip`.

Dart side: `FlutterAndroidClipboard.writeText` switches from `Clipboard.setData` to the
channel's `writeText`, so text and image share one native path and one failure taxonomy.
`MainActivity` drops its `imagesync/clipboard` registration (the multicast channel
stays). The UI-isolate tap handler uses the same channel — it works there too.

### D2 — The service writes the clipboard directly on arrival

`PayloadReceiver` keeps its current shape: save to repository first (source of truth),
then attempt the clipboard write, then notify. No screen-on gate, no Doze gate — the
AOSP write path has neither (research Q3); if the socket delivered the frame, we write.
The repository-first order is load-bearing: whatever happens to the write, the
notification tap can always re-copy from the repository.

### D3 — Failure taxonomy and MIUI detection

The write attempt resolves to one of three outcomes:

| Outcome | Signal | Treatment |
| --- | --- | --- |
| Confirmed write | channel returns success | zero-tap succeeded (on AOSP this is trustworthy) |
| Blocked | `SecurityException` from `setPrimaryClip` (MIUI privacy layer, flutter/flutter#102300) | failure receipt + one-time MIUI hint |
| Wiring bug | `MissingPluginException` | failure receipt; log loudly to the debug log — this is a regression, not a device policy |

**MIUI silent no-op is not reliably detectable from the background.** Read-back
verification is impossible: `OP_READ_CLIPBOARD` (and primary-clip-changed listener
dispatch) requires focus or default-IME status on Android 10+, so a background service
cannot confirm its own write landed. The spec therefore treats "no exception" as
success and accepts that some MIUI devices may silently drop writes until the user
flips the MIUI Clipboard permission. Mitigations:

- **One-time MIUI hint** on `SecurityException`: a normal-importance notification shown
  at most once (flag persisted in settings storage), text directing the user to enable
  the Clipboard permission for ImageSync. Tap fires the community-known MIUI permission
  editor intent (`miui.intent.action.APP_PERM_EDITOR` with the package extra), falling
  back to the standard app-details settings screen if that activity doesn't resolve.
  The intent is community-sourced/unverified — execution must verify it on the real
  device and keep the fallback.
- **Proactive setup on Xiaomi devices** (showing the hint during onboarding rather than
  waiting for a failure) belongs to the
  [Onboarding and permissions flow spec (#30)](https://github.com/Snehit70/imagesync/issues/30),
  not here.
- The tap-to-copy receipt (D4) remains the universal fallback either way.

### D4 — Quiet receipt replaces the alerting notification

The current `imagesync_payloads` channel is `Importance.high` (heads-up + sound).
Android fixes a channel's importance at creation and won't let the app lower it later,
so the quiet receipt needs a **new channel**: `imagesync_receipts`, `Importance.low`
(no sound, no heads-up, silent in the shade). Execution deletes the old
`imagesync_payloads` channel on upgrade so stale high-importance behavior doesn't
linger on existing installs.

One receipt notification per received payload, on the new channel, replacing (not
adding to) today's flow in `LocalPayloadNotifier`:

- **Write confirmed:** title "Copied from laptop", body = text preview (existing 80-char
  preview) or "Image (mime)". Tap still carries the existing copy payload — harmless
  idempotent re-copy.
- **Write failed:** title "Received from laptop", body "Tap to copy" + preview. Same tap
  payload; this is the MIUI-blocked fallback the map's product decision names.
- Fixed notification id (replace-in-place) instead of today's timestamp-derived id, so
  a burst of payloads doesn't stack receipts; only the latest payload is copyable from
  the repository anyway.

The `showReceiveNotifications` settings toggle keeps its meaning with one carve-out:
it suppresses **success** receipts only. Failure receipts always show, because when the
direct write fails the notification tap is the only delivery path — suppressing it
would silently drop payloads.

### D5 — Coexistence with `ReceiveNotificationTapHandler`

Unchanged. The tap handler's warm (callback) and cold (launch-details) paths, the
`copyLatestText/ImageNotificationPayload` constants, and the repository-backed
`_copyLatest*` logic all stay as-is — the receipt notification carries the same payload
strings, so taps keep working. After D1 the tap handler's writes also go through the
plugin channel, removing the duplicated clipboard implementations. Tap-after-success
is an idempotent re-copy; no special-casing.

## Acceptance criteria (for the execution effort)

1. Stock-Android behavior: with the app backgrounded and screen off, a text or image
   sent from the laptop is on the phone clipboard with zero taps, and a silent
   low-importance receipt appears. No heads-up, no sound.
2. Service-isolate write path verified on the real device via the debug log: outcome
   logged as confirmed / blocked / wiring-bug per D3.
3. MIUI blocked path: forcing a `SecurityException` (or observing one on the Poco
   device) produces the one-time hint exactly once, and its tap opens the MIUI
   permission editor or the app-details fallback.
4. Notification tap (warm and cold) still copies the latest payload.
5. `showReceiveNotifications` off: success receipts suppressed, failure receipts shown.

## Out of scope here

- Proactive MIUI permission onboarding — #30.
- Latency measurement against the ≤2s bar — #26 defines measurement.
- Socket delivery/wake behavior that gets the frame to the phone at all — #24.
