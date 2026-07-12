# Opt-in READ_LOGS auto-text mode

Spec for Seamless Sync ticket [#31](https://github.com/Snehit70/vidyut/issues/31).
Research basis: [`docs/research/android-seamless-sync.md`](../research/android-seamless-sync.md) Q2
(AOSP `ClipboardService` read gate; KDE Connect's shipped READ_LOGS recipe).

**Goal:** the last phase of Seamless Sync — automatic phone→laptop *text* push on copy,
with zero taps, for the user willing to run a one-time ADB grant. This is a port of KDE
Connect's `ClipboardListener` + `ClipboardFloatingActivity` recipe. It is **opt-in,
advanced, and default-off**: every path degrades to today's manual "Send clipboard" +
share sheet when the grant is absent, so a normal install is unaffected.

Scope boundary: this spec ends at *copied text handed to the existing publish path*.
Screenshots (Q1, #27/#28) and laptop→phone receive (Q3, #29) are their own specs and
carry the primary zero-tap story; text auto-send is the fragile, gated extra.

## Why this needs a hack at all

AOSP enforces (research Q2, `ClipboardService.clipboardAccessAllowed`, android-15.0.0_r1):
`OP_READ_CLIPBOARD` is allowed **only** for the focused app, the default IME, or a
signature/privileged holder of `READ_CLIPBOARD_IN_BACKGROUND`. A background foreground
service is none of these, so it cannot read the clipboard, and cannot even receive
`OnPrimaryClipChangedListener` callbacks in the background. Every copied-text-on-change
path therefore fails by design. KDE's recipe works *around* the gate rather than through
it, and is the only stock-ish option that stays zero-tap; the default IME path is a
non-starter and AccessibilityService can't read arbitrary clipboard (both rejected in
research Q2).

Today Vidyut already has the *manual* version of the trick: `SendClipboardScreen`
(`app/lib/src/foreground/send_clipboard_screen.dart`) works precisely because it runs in
`MainActivity` — an Activity with focus — so `Clipboard.getData` is permitted. The
auto-mode is "do that read, invisibly, the instant something is copied, without the user
tapping."

## The mechanism (KDE Connect port)

Three cooperating native pieces, all owned by the foreground service's process, plus one
Dart hop to reuse the existing encrypt-and-publish path:

1. **Clip-change listener as a trip-wire.** Register an `OnPrimaryClipChangedListener` on
   the application-context `ClipboardManager` from the service. On Android 10+ its
   callback is suppressed in the background — but *registering* it makes the system
   attempt to dispatch on each copy, which the platform then **denies and logs**. We do
   not read from this listener; it exists to provoke the denial log below. (On API < 29
   the callback fires directly and can read — see [Version branches](#version-branches).)

2. **Logcat watcher filtered to ClipboardService denials.** A background thread in the
   service spawns a long-lived `logcat` subprocess and scans its lines for a
   ClipboardService "Denying clipboard access to `<our package>`" entry (AOSP logs this at
   `ClipboardService.java:1388-1392`). Seeing our own package id in a denial line **is**
   the "clipboard just changed" signal. Command shape (from KDE's `ClipboardListener.kt`):

   ```
   logcat -T <startTimestamp> <priorityFilter> "*:S"
   ```

   `-T <startTimestamp>` starts the tail at service-start so we never replay stale
   denials; `*:S` silences every other tag. `<priorityFilter>` is version-branched
   (below). This process yields nothing useful unless `READ_LOGS` is granted — without it
   `logcat` only returns our own app's log lines, never the system ClipboardService tag,
   so the watcher is inert (this is the degradation gate, D-Degrade).

3. **Invisible focus-stealing activity.** On a matching denial line, launch a transparent,
   input-less `ClipboardReadActivity`. It takes focus for an instant, reads the clipboard
   in `onWindowFocusChanged(hasFocus=true)` (now permitted — it is the focused app),
   forwards the text, and immediately `finish()`es. Header semantics mirror KDE's
   `ClipboardFloatingActivity`: "invisible and doesn't require any interaction from the
   user."

## Decisions

### D1 — Opt-in, additive, default-off; manual paths never change

A new setting `enableClipboardAutoSend` (default **false**) on `AppSettings`
(`app/lib/src/settings/app_settings.dart`). The mode is *effective* only when both the
setting is on **and** `READ_LOGS` is granted — mirror of KDE's
`ClipboardPlugin.canSyncAutomatically()` (`= READ_LOGS granted` on Q+).

The existing manual surfaces are untouched regardless: `SendClipboardScreen`, the
persistent-notification "Send clipboard" action, and the OS share sheet remain the
default and the fallback. Auto-mode adds a path; it removes none. This matches KDE
demoting (not deleting) its manual "Send clipboard" button when auto is available.

### D2 — Native logcat watcher owned by the foreground service

A native component (`ClipboardAutoSendWatcher`, Kotlin) started/stopped from the service
lifecycle, exposed to Dart through a local plugin channel — same plugin-package pattern
the screenshot observer (#27) and clipboard writer (#29) adopt, so it auto-registers in
the headless service engine via `GeneratedPluginRegistrant`. State (the `logcat`
`Process`, its reader thread, the registered `OnPrimaryClipChangedListener`) lives in a
**process-wide singleton** so a service restart never leaks a second `logcat` process.
`start` is idempotent; `stop` tears down the subprocess (`Process.destroy()`), joins the
reader thread, and unregisters the listener.

Wiring point: `ServiceRelayController._sync()` already loads settings on every
(re)connect; it reconciles the watcher the same way #27 reconciles the screenshot
observer — start when `enableClipboardAutoSend` is on and `READ_LOGS` is granted, stop
otherwise. `stop()` (service `onDestroy`) tears it down.

### D3 — Read result reuses the one publish path; no second sender

`ClipboardReadActivity` reads text natively, then forwards it into the service isolate
over the plugin channel; the service publishes it through the **existing**
`SharePublisher.publish(SharePayload.text(...))` used by the manual screen. Rationale:
one encryption/pairing/`ts`-stamping path, one failure taxonomy, and the auto and manual
sends are indistinguishable on the wire. The activity never opens its own socket.

If the service isn't running when a denial fires (auto-send on but service stopped), the
watcher isn't running either (D2 ties it to service lifetime), so this case can't occur —
no orphan-read handling needed.

### D4 — Echo/loop guard against received-then-rewritten clipboard

Laptop→phone receive (#29) **writes** the phone clipboard. That write trips the
`OnPrimaryClipChangedListener` → denial → auto-read → re-publish of the just-received text
back to the laptop → infinite echo. The guard: the service records the exact text it last
wrote to the clipboard on behalf of a received payload (in-memory, service-isolate); an
auto-read whose text equals that recorded value is **dropped before publish**. KDE avoids
the analogous loop with last-writer-wins timestamp compare on `kdeconnect.clipboard`; a
content-equality check against the last locally-applied write is the minimal equivalent
here and needs no wire change. The record is cleared once consumed so a genuine re-copy of
the same text by the user still sends.

### D5 — Invisible activity: manifest and background-activity-start

`ClipboardReadActivity` manifest entry (`AndroidManifest.xml`):

- a fully transparent theme (translucent window, no title, no dim), no layout content;
- `android:excludeFromRecents="true"`, `android:noHistory="true"`,
  `android:exported="false"`, `android:launchMode="singleInstance"` so bursts collapse and
  it never appears in the recents/overview.

**Background-activity-start caveat (Android 10+):** launching an Activity from a
background service is restricted. KDE's reliability lever is the `SYSTEM_ALERT_WINDOW`
appop ("draw over other apps"), granted in the same one-time ADB block (D6); with it the
invisible-activity launch is permitted from the background. **MIUI/HyperOS
([UNVERIFIED], research Q2):** additionally gates both background-activity-start and
draw-over-other-apps behind its own per-app toggles, so on Xiaomi the ADB `appops` grant
may still not suffice without the MIUI "Display pop-up windows while running in the
background" permission. The advanced-settings screen (D6) states this caveat; the deep
MIUI toggle UX is onboarding's job (#30), not duplicated here.

### D6 — One-time ADB setup surfaced in an advanced-settings screen

A new **Advanced → Clipboard auto-send** screen, reached from Settings, gated behind an
"advanced" affordance so a normal user never lands on ADB instructions. It shows:

- a one-line honest description ("Automatic send-on-copy for text. Requires a one-time
  computer setup and does not work on every phone.");
- the `enableClipboardAutoSend` toggle;
- live grant state: `READ_LOGS granted` vs. `not granted — run the setup below`
  (`checkSelfPermission(READ_LOGS)`), re-checked on each return-to-foreground since the
  grant is external;
- the exact copy-paste commands, with a copy button, for **`dev.snehit.vidyut.vidyut`**
  (the app's `applicationId`):

  ```
  adb -d shell pm grant dev.snehit.vidyut.vidyut android.permission.READ_LOGS
  adb -d shell appops set dev.snehit.vidyut.vidyut SYSTEM_ALERT_WINDOW allow
  adb -d shell am force-stop dev.snehit.vidyut.vidyut
  ```

- the MIUI caveat line from D5.

`READ_LOGS` is grantable **only** via ADB (not a runtime permission dialog), so there is
no in-app request button — the commands are the whole flow. The `force-stop` is required
so the app re-reads its now-granted permissions.

### D-Degrade — Behavior by grant/setting state

| `enableClipboardAutoSend` | `READ_LOGS` | Behavior |
| --- | --- | --- |
| off (default) | any | Auto mode fully inert. Manual "Send clipboard" + share sheet only. |
| on | not granted | Watcher won't start (`logcat` sees no system tag). Advanced screen shows "not granted"; manual paths still work. No silent-broken state — the screen reflects it. |
| on | granted | Auto send-on-copy active. Manual paths remain as backup. |

No path throws a user-visible error for a missing grant; the advanced screen's grant-state
line is the single source of truth.

### Version branches

- **API ≥ 35 (Android 15, `VANILLA_ICE_CREAM`):** priority filter `"E ClipboardService"`.
- **API 29–34 (Android 10–14):** priority filter `"ClipboardService:E"`.
  (KDE switched syntax at the Android 15 boundary — `ClipboardListener.kt:51`.)
- **API < 29 (Android ≤ 9):** background clipboard reads are permitted; the
  `OnPrimaryClipChangedListener` callback reads directly with no logcat/activity hack and
  no `READ_LOGS`. `minSdk` is 24, so this branch is reachable, but the target devices
  (MIUI/HyperOS, modern) are all Q+; the legacy branch is a documented accepted path, not
  a design driver, and may be deferred to execution if it isn't worth the code.

## Instrumentation

Each stage logs through the existing service debug log (`emit({'kind':'log', ...})`) so
the fragile pieces are diagnosable on the real device without new tooling:

- watcher started (with the chosen priority filter and Android API level);
- denial line matched (redacted — never log clipboard contents);
- invisible activity focused / read `N` chars / finished;
- echo-guard drop (D4) vs. forwarded-to-publish;
- publish outcome (reusing `SharePublisher`'s result, as the manual path already logs).

## Acceptance criteria (for the execution effort)

1. With `enableClipboardAutoSend` off (default), no `logcat` process is spawned and no
   behavior differs from today — verifiable in the debug log and `ps`.
2. With the setting on but `READ_LOGS` **not** granted, the advanced screen shows "not
   granted", nothing is auto-sent, and the manual send still works.
3. After running the ADB block on a stock Android 13/14/15 device, copying text in any app
   lands it on the laptop within the map's ≤2s screen-on bar, with no tap.
4. Receiving text from the laptop (#29) does **not** bounce back to the laptop (echo guard
   D4 verified in the debug log).
5. The invisible activity never appears in recents and shows no visible UI flash.
6. Version branch: the correct `logcat` priority filter is selected for the device's API
   level (assert in the watcher's start log).

## Out of scope here

- Implementation — a later effort executes this plan (map is plan-only).
- MIUI deep-link onboarding for background-activity-start / draw-over-other-apps toggles —
  [Onboarding and permissions flow (#30)](https://github.com/Snehit70/vidyut/issues/30).
- Screenshot (#27/#28) and receive (#29) paths — their own specs.
- Default-IME and AccessibilityService clipboard reading — rejected in research Q2.
- Latency measurement methodology against the ≤2s bar — the relay-observability spec (#25)
  and #26 define measurement; auto-sent text rides the same `SharePublisher`/relay path.
