# Seamless Sync — implementation plan

Resolves [#32 Assemble the seamless-sync implementation plan](https://github.com/Snehit70/imagesync/issues/32),
the final ticket of the [Seamless Sync map](https://github.com/Snehit70/imagesync/issues/23).

This is the execution-ready collation of the map's seven locked specs. Every design
decision is already made; each work package below points at the spec that owns its
decisions, lists the file-level touchpoints, and states its done-condition. A session
implementing a package should read its owning spec(s) in full — this plan orders and
scopes, the specs decide.

**Success bar (map-locked):** ≤2s device-to-device while the phone screen is on;
delivery by next reconnect/wake while dozing. Measurement is defined per direction in
[Verification](#verification) and scripted in `docs/E2E.md` §8–§12.

## Spec index

| Spec | Ticket | Owns |
| --- | --- | --- |
| [`relay-observability.md`](relay-observability.md) | [#25](https://github.com/Snehit70/imagesync/issues/25) | Relay/laptop JSON log events, correlation keys, bar measurement from relay stdout |
| [`zero-tap-receive.md`](zero-tap-receive.md) | [#29](https://github.com/Snehit70/imagesync/issues/29) | Clipboard plugin, silent service-side write, failure taxonomy, quiet receipts |
| [`keepalive-reconnect.md`](keepalive-reconnect.md) | [#24](https://github.com/Snehit70/imagesync/issues/24) | WS pings, connect timeout, backoff retune, screen-on reconnect trigger |
| [`screenshot-observer.md`](screenshot-observer.md) | [#27](https://github.com/Snehit70/imagesync/issues/27) | Observer plugin, MIUI-safe filter, dedup/watermark, permission grant states |
| [`screenshot-auto-push.md`](screenshot-auto-push.md) | [#28](https://github.com/Snehit70/imagesync/issues/28) | Push controller, latest-wins slot, offline hold + ack, crypto cost fixes, toggle |
| [`onboarding-permissions.md`](onboarding-permissions.md) | [#30](https://github.com/Snehit70/imagesync/issues/30) | First-run wizard, setup checklist, MIUI guide, settings additions |
| [`read-logs-auto-text.md`](read-logs-auto-text.md) | [#31](https://github.com/Snehit70/imagesync/issues/31) | Opt-in READ_LOGS auto-text mode, echo guard, advanced screen |
| Notification-surface decisions | [#33](https://github.com/Snehit70/imagesync/issues/33) | What survives after zero-tap (resolution comment on the ticket — no spec file) |

Grounding research (primary-source cited): `docs/research/android-seamless-sync.md`.
Survival measurements (freeze-not-flap; lock-in-recents = zero drops over 67+ min):
[#26](https://github.com/Snehit70/imagesync/issues/26).

## Cross-cutting foundations

Decisions several packages share; established once, reused everywhere.

1. **App-local Flutter plugins for anything the service isolate must reach.**
   `flutter_foreground_task` builds the service's headless `FlutterEngine` with
   automatic plugin registration, so a real plugin (class implementing
   `FlutterPlugin`, listed in `GeneratedPluginRegistrant`) attaches to **both** the
   activity engine and the service engine with no per-engine wiring —
   `MainActivity.configureFlutterEngine` channels are activity-engine-only and are the
   root cause of today's structurally broken service-side clipboard writes. All local
   plugins live under **`app/packages/`** as path dependencies in `app/pubspec.yaml`
   (the observer spec's location; `zero-tap-receive.md`'s `app/plugins/` was an "e.g."):
   - `app/packages/imagesync_clipboard/` — clipboard writes (WP2), plus the
     application-context grab-bag: MIUI manufacturer check (#30 D4) and the screen-on
     receiver (WP3, per keepalive D5 "same app-local plugin mechanism").
   - `app/packages/screenshot_observer/` — MediaStore observer + `readImage` (WP4/WP5).
   - `app/packages/clipboard_autosend/` — READ_LOGS watcher + invisible read activity (WP8).

   Native watcher/observer state always lives in a **process-wide singleton** (idempotent
   `start`, safe `stop`), never in the plugin instance — both engines instantiate the plugin.

2. **The service isolate owns every background behavior.**
   `ServiceRelayController._sync()` is the single reconciliation point: it already loads
   settings on every (re)connect and gains the watcher/pipeline start-stop logic
   (screenshot observer per observer §6, auto-send watcher per read-logs D2). UI flips a
   toggle → sends the existing `serviceSyncCommand` → `_sync()` reconciles. Nothing is
   forwarded to the UI isolate except debug-log lines via the existing
   `emit({'kind': 'log', ...})` channel.

3. **Instrumentation rides existing loggers.** Relay/laptop events go through
   `src/relay/logger.ts` (one JSON object per line, `message` = snake_case event name);
   phone events through the existing in-app debug log. Event names and fields are fixed
   by `relay-observability.md` and `screenshot-auto-push.md` §8 — implement them exactly,
   the verification scripts grep for them.

4. **Copy strings:** where two specs word the same control differently, #30 owns
   settings/onboarding copy (e.g. the toggle backed by the `autoPushScreenshots` field
   is labeled "Auto-send screenshots" per #30 D8; #28's "Auto-push screenshots" was the
   working name). Exact strings may be polished during execution; the load-bearing
   *claims* in #30 D7 must not be weakened.

## Work packages

Ordered by dependency; each sized for one session. "Done when" points at the owning
spec's acceptance criteria (AC) — those are the package's exit tests.

### WP1 — Relay and laptop observability

Everything else is measured through these events; land them first.
**Spec:** `relay-observability.md` (all of it). **Depends on:** nothing.

- `src/relay/relay.ts` — `connId` at upgrade + `connectedAt` in socket data; emit
  `device_connected`, `auth_ok{msSinceConnect}`, `auth_failed`, `device_disconnected{wsCode,wsReason}`,
  `socket_reaped{idleMs}` (exactly one terminal event per connection), `client_error_sent`,
  `payload_published{nonce,frameTs,relayLagMs}`, `payload_stale_dropped`,
  `payload_broadcast{recipients, replay}`.
- `src/relay/clipboard-sync.ts` — `clipboard_published`, `clipboard_write{e2eMs}`,
  `clipboard_write_failed{stage}` (stop swallowing via `Promise.allSettled`).
- `src/relay/cli.ts` — pass the real logger to `createRelay` and `startClipboardSync`
  (both gain an optional `logger` option, no-op default so existing tests stay silent).

**Done when:** every event in the spec's tables appears in relay stdout during a manual
send/receive; the three `jq` filters in [Verification](#verification) return data.

### WP2 — Clipboard plugin and zero-tap receive

Establishes the local-plugin pattern and makes laptop→phone zero-tap.
**Spec:** `zero-tap-receive.md` (D1–D5). **Depends on:** nothing (WP1 only for measuring).

- New `app/packages/imagesync_clipboard/` — Kotlin `FlutterPlugin` registering the
  `imagesync/clipboard` MethodChannel from **application context**; `writeText`,
  `writeImage(path, mime)` (moved verbatim from `MainActivity`).
- `app/android/app/src/main/kotlin/dev/snehit/imagesync/imagesync/MainActivity.kt` —
  drop the `imagesync/clipboard` registration (multicast channel stays).
- `app/lib/src/receive/payload_receiver.dart` — direct write on arrival,
  repository-first; resolve to confirmed / blocked (`SecurityException` → one-time MIUI
  hint, flag persisted in settings) / wiring-bug (`MissingPluginException` → loud debug log).
- `LocalPayloadNotifier` (in `payload_receiver.dart`) — new `imagesync_receipts` channel,
  `Importance.low`; delete the old `imagesync_payloads` channel on upgrade; fixed
  notification id (replace-in-place); "Copied from laptop" vs "Received from laptop —
  tap to copy" per D4.
- `app/lib/src/receive/receive_notification_tap_handler.dart` — unchanged flow, writes
  now via the plugin channel; `FlutterAndroidClipboard.writeText` switches off
  `Clipboard.setData`.
- `app/lib/src/settings/*` — `showReceiveNotifications` carve-out: suppresses success
  receipts only, failure receipts always show (subtitle copy per #30 D8).

**Done when:** zero-tap-receive AC 1–5 pass on the real devices.

### WP3 — Keepalive and reconnect

**Spec:** `keepalive-reconnect.md` (D1–D7). **Depends on:** WP2 (plugin host for the
screen-on receiver), WP1 (auth_ok / reap events for measurement).

- `app/lib/src/shared/relay_connection.dart` — `WebSocketRelayTransport.connect`
  switches to `IOWebSocketChannel.connect(uri, pingInterval: 30s, connectTimeout: 5s)`;
  socket-closed debug event gains `closeCode`/`closeReason`.
- `app/lib/src/foreground/service_relay_controller.dart` — backoff `[2, 4, 8, 16, 32]`
  (cap 32s, curve shape kept; attempt reset semantics unchanged).
- `app/packages/imagesync_clipboard/` — `ACTION_SCREEN_ON` `BroadcastReceiver` registered
  from the service, delivering a `sync`-equivalent to `ServiceRelayController` (reset
  attempts + reconnect if not connected; no-op when connected).
- `src/relay/relay.ts` — wire Bun's `ping(ws)` callback to refresh `lastSeen`;
  heartbeat constants (30s ping / 90s reap) unchanged.

**Done when:** screen-on trigger → `auth_ok` ≤2s (E2E §11); idle survival re-run shows
zero `socket_reaped` over ≥60 min (E2E §12).

### WP4 — Screenshot observer plugin

**Spec:** `screenshot-observer.md` (all sections). **Depends on:** nothing hard
(reuses the WP2 plugin pattern).

- New `app/packages/screenshot_observer/` — `ScreenshotObserverPlugin.kt` + singleton
  `ScreenshotWatcher`: `ContentObserver` on `EXTERNAL_CONTENT_URI` (application-context
  resolver), dedicated `HandlerThread`, 500ms debounce → 30s-window query → watermark +
  64-entry LRU id dedup → bucket-name "Screenshots" / display-name "screenshot" filter.
  Channels: `imagesync/screenshot_observer` (`start`/`stop`/`accessLevel`) and
  `imagesync/screenshot_events` (event JSON per §3).
- `app/android/app/src/main/AndroidManifest.xml` — `READ_MEDIA_IMAGES` +
  `READ_EXTERNAL_STORAGE maxSdkVersion=32`; **do not** declare
  `READ_MEDIA_VISUAL_USER_SELECTED` (§5 — partial grant silently breaks detection).
- `app/lib/src/foreground/service_relay_controller.dart` — injected screenshot-watcher
  collaborator; `_sync()` starts it when `autoPushScreenshots` is on and access is
  `full`, stops otherwise; `stop()` tears it down. Paused state ("auto-push paused —
  allow all photos") surfaces per §5 when the setting is on but access isn't full.
- `app/lib/src/settings/app_settings.dart` (+ repository) — `autoPushScreenshots`
  field, default `true` (UI lands in WP6).

**Done when:** on the Poco, a screenshot logs the §7 chain (onChange → query → emitted)
in the debug log; camera photos and downloads emit nothing; partial grant → paused state.

### WP5 — Screenshot auto-push pipeline

**Spec:** `screenshot-auto-push.md` (all sections). **Depends on:** WP4 (events,
`readImage` host), WP1 (`e2eMs`), WP3 (reconnect that triggers republish).

- New `app/lib/src/push/screenshot_push_controller.dart` — long-lived controller in the
  service isolate; single-slot latest-wins pending frame; publish on `connected`, hold
  offline, verbatim republish on reconnect, clear only on relay ack; drop pending on
  `payload_too_large`.
- `app/packages/screenshot_observer/` — `readImage(id)` → `Uint8List` on the observer
  `HandlerThread`; 3 attempts / 300ms on `not-found`/`io-error`; size guard before read.
- `app/lib/src/shared/relay_connection.dart` — capture and expose `hello.maxPayloadBytes`
  (currently discarded); surface acks as a `Stream<int>` of acked `ts`.
- `app/lib/src/shared/payload_crypto.dart` — memoize the PBKDF2-derived key per pairing
  secret; enable `cryptography_flutter` (`FlutterCryptography.enable()`; verify via
  `encryptMs` logs that the native path holds in the headless engine).
- `app/lib/src/foreground/imagesync_foreground_service.dart` — construct/inject the
  controller in `_relayController()`; `_sync()` attaches sessions, `_teardown()` detaches.
- Instrumentation: the seven `screenshot_*` events of §8, exactly as named.

**Done when:** screenshot-auto-push AC 1–7 pass (they are the package's test list,
including the ≤2s median over ≥10 samples and the offline-hold/ack drills).

### WP6 — Onboarding wizard, setup checklist, settings additions

**Spec:** `onboarding-permissions.md` (D1–D9). **Depends on:** WP2 (clipboard plugin
hosts the MIUI manufacturer check; SecurityException un-check feedback), WP4
(`accessLevel()` drives the photos step and paused banner).

- New onboarding feature dir (suggested `app/lib/src/onboarding/`) — wizard (5 steps,
  D2 order, all skippable), `SetupStatus` model (D6), setup-checklist screen, home-screen
  banner (`app/lib/main.dart` home).
- `app/android/app/src/main/AndroidManifest.xml` — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- `app/packages/imagesync_clipboard/` — manufacturer method (D4); MIUI deep-link intents
  fired with resolve-check + `ACTION_APPLICATION_DETAILS_SETTINGS` fallback (D5; all
  community-sourced — verify each on the Poco).
- `app/lib/src/settings/settings_screen.dart` — "Auto-send screenshots" toggle (sends
  `serviceSyncCommand`), "Setup status" row with summary chip, receive-toggle subtitle
  update (D8).
- Settings storage — `onboardingComplete`, four MIUI self-report flags; a clipboard
  `SecurityException` (WP2 taxonomy) un-checks the Clipboard item.
- Visual language per D9 (existing `design/theme.dart` / `design/palette.dart` vocabulary).

**Done when:** onboarding-permissions AC 1–7 pass (fresh-install wizard, skip states,
partial-grant recovery, live checklist, MIUI deep-links on-device).

### WP7 — Notification-surface simplification

**Decisions:** [#33 resolution comment](https://github.com/Snehit70/imagesync/issues/33).
**Depends on:** WP2 (receipts exist), WP4/WP5 (paused state + toggle exist). Mostly copy
and one setting re-scope; can ride with WP6 in a session if it fits.

- `app/lib/src/settings/*` — `showPersistentSendNotification` re-scoped as the
  **"Background sync" master switch** (same FGS gate; field rename/migration is an
  execution detail — a migration must preserve the user's current value).
- `app/lib/src/foreground/imagesync_foreground_service.dart` — status text stays
  connection-state-only; connected copy rewritten for zero-tap (e.g. "Synced with laptop —
  clipboard and screenshots"); observer-spec paused state slots in; "Send clipboard"
  button stays unconditionally; no per-event text updates, no new per-payload surfaces.
- All current screens survive: `SendClipboardScreen`, settings, debug log, home status
  cards (auto-push results may feed the send card over the existing `emit` channel).

**Done when:** notification shows the new copy in each state (connected / searching /
offline / paused); toggling "Background sync" off stops the service and all sync; the
send button still opens `SendClipboardScreen`.

### WP8 — Opt-in READ_LOGS auto-text mode

**Spec:** `read-logs-auto-text.md` (all sections). **Depends on:** WP2 (echo guard needs
the service's record of its last clipboard write; plugin pattern). Last app package —
it's the gated extra and touches nothing on the primary paths.

- New `app/packages/clipboard_autosend/` — singleton `ClipboardAutoSendWatcher`
  (trip-wire `OnPrimaryClipChangedListener` + long-lived `logcat -T <start> <filter> "*:S"`
  subprocess, version-branched filter: API≥35 `"E ClipboardService"`, 29–34
  `"ClipboardService:E"`; API<29 direct-read branch may be deferred), and the transparent
  `ClipboardReadActivity` (manifest per D5: excludeFromRecents, noHistory, not exported,
  singleInstance) reading in `onWindowFocusChanged` and forwarding over the channel.
- `app/lib/src/settings/app_settings.dart` — `enableClipboardAutoSend`, default `false`.
- `app/lib/src/foreground/service_relay_controller.dart` — `_sync()` reconciles the
  watcher (on ⟺ setting on **and** `READ_LOGS` granted); echo guard: drop an auto-read
  equal to the last received-payload write (record cleared once consumed).
- Publish path: forward into the existing `SharePublisher.publish(SharePayload.text(...))`
  — no second sender.
- New Advanced → Clipboard auto-send screen off `settings_screen.dart` — toggle, live
  grant state, copy-paste adb block for `dev.snehit.imagesync.imagesync`, MIUI caveat line.

**Done when:** read-logs-auto-text AC 1–6 pass (default-off inertness, degraded-state
honesty, post-grant ≤2s send-on-copy, echo-guard, invisible activity, filter branch).

### WP9 — Verification run and sign-off

**Depends on:** everything. Run `docs/E2E.md` end to end — the original §0–§7 (nothing
regressed) plus the new §8–§12 (seamless sync). Record the run in both results tables.
This is the map's destination test: the plan is delivered when a recorded run is green.

## Verification

How the bar is measured (collated from the specs; scripted as `docs/E2E.md` §8–§12):

- **Phone → laptop screen-on ≤2s:** per screenshot,
  `captureToDetectMs` (phone debug log, observer §7) + `e2eMs` (relay `clipboard_write`)
  ≤ 2000ms — median over ≥10 samples on the set-up Poco.
  `journalctl --user -u imagesync-relay -o cat | jq -r 'select(.message=="clipboard_write") | .e2eMs'`
- **Laptop → phone:** phone receipt time − `frameTs` from the phone debug log (the relay
  sees only its half). Clock-skew caveat: NTP-synced devices, <100ms, negligible vs 2s.
- **Doze delivery:** a payload with `payload_broadcast.recipients: 0` must be followed by
  `device_connected → auth_ok → payload_broadcast{replay: true}` for that device; the
  delivery gap is `auth_ok.ts − payload_published.ts`. Phone-side mirror:
  `screenshot_held` → `screenshot_republished{heldForMs}`.
- **Screen-on reconnect:** phone debug-log line at the screen-on trigger → relay
  `auth_ok{connId}` ≤ 2s.
- **Idle survival:** ≥60 min screen-off with MIUI toggles applied (lock-in-recents +
  hibernation off + battery exemption), keepalive active. Acceptance: **zero**
  `socket_reaped`; every disconnect attributable via `wsCode`/`idleMs`.
  `journalctl --user -u imagesync-relay -o cat | jq -r 'select(.message=="socket_reaped")'` → empty.

## Acceptance checklist (map destination)

The per-package spec ACs are the fine grain; this is the top-level sign-off, mirrored
in `docs/E2E.md` §8–§12:

- [ ] Laptop copy → phone clipboard with zero taps, silent quiet receipt (no heads-up, no sound); failure receipts always shown; tap-to-copy fallback works warm and cold.
- [ ] Phone screenshot (screen on, app backgrounded) → laptop clipboard with zero taps; `captureToDetectMs + e2eMs ≤ 2000` median over ≥10 samples.
- [ ] Burst of screenshots → newest wins, `superseded` skips logged, no crash.
- [ ] Screenshot while relay down / phone dozing → delivered on next reconnect/wake (hold → verbatim republish → single ack).
- [ ] ≥60 min idle, screen off, MIUI toggles applied → zero `socket_reaped`; screen-on after a dead socket reconnects and auths in ≤2s.
- [ ] Fresh install: wizard runs once in order, every step skippable, checklist reflects live state, MIUI deep-links verified on the Poco.
- [ ] Notification surface: new connection-state copy, paused state, "Background sync" master switch, "Send clipboard" button intact.
- [ ] READ_LOGS mode: inert by default; after the adb block, copy-on-phone lands on the laptop ≤2s with no tap; no echo loop.
- [ ] v1 E2E §0–§7 still green (no regression).

## Execution notes

- **Real-device dependence:** MIUI intents (#30 D5, #29 D3's `APP_PERM_EDITOR`), the
  headless-engine native-crypto path (#28 §4), and the READ_LOGS recipe (#31) are all
  flagged UNVERIFIED in their specs — each has a specified fallback; verify on the Poco
  during its package, don't front-load.
- **Out of scope (map-locked):** Play Store/signed releases, non-LAN transport,
  clipboard history, AccessibilityService clipboard reading, finishing the v1 E2E audit
  (that's the [v1 map](https://github.com/Snehit70/imagesync/issues/9)'s #22).
- **Contingency:** if execution-time idle measurement contradicts #26 (reaps despite
  toggles + exemption + keepalive), the ladder is MIUI Autostart first, then a
  WorkManager nudge as a fresh effort (`keepalive-reconnect.md` Contingency).
