# Onboarding and permissions flow

Spec for Seamless Sync ticket [#30](https://github.com/Snehit70/vidyut/issues/30).
Consumes the grant-state contract from
[`screenshot-observer.md`](screenshot-observer.md) §5 and the MIUI clipboard hint from
[`zero-tap-receive.md`](zero-tap-receive.md) D3.

**Goal:** a first run that ends with every permission granted correctly and the phone
paired — and a persistent surface that shows, at any later moment, exactly what is
degraded and how to fix it.

## Current state

Today the app requests only the notification permission
(`FlutterForegroundTask.requestNotificationPermission()` at service start, see
`vidyut_foreground_service.dart`). There is no photos-access request, no
battery-exemption prompt, no MIUI guidance, and no onboarding UI. Pairing is a separate
flow. Settings has two toggles (receive notifications, persistent send notification).

## Decisions

### D1 — Shape: first-run wizard + persistent setup checklist

Two surfaces, one source of truth:

- **Wizard** — a one-time sequential first-run flow (full-screen steps) that walks the
  user through the grants in order and ends with pairing. Gated by an
  `onboardingComplete` flag in settings storage; never force-re-shown.
- **Setup checklist** — a screen reachable any time from Settings ("Setup status")
  listing every item with its **live** state. This is the recovery surface for
  everything that can degrade later (partial photos grant, revoked battery exemption,
  MIUI toggles) and the home of the unverifiable MIUI steps.

Both render from the same status model (D6). While `onboardingComplete` is false, or
any live-verifiable item is unhealthy while its feature is enabled, the home screen
shows a banner ("Finish setup" / "Auto-push paused — allow all photos") that opens the
wizard resp. the checklist. This banner is the "in-app" half of the paused-state
contract in `screenshot-observer.md` §5.

### D2 — Step order and skippability

Wizard steps, in order:

1. Notifications
2. Photos access ("Allow all")
3. Battery exemption
4. Xiaomi device setup (shown only on MIUI, D5)
5. Connect to your laptop (existing pairing flow embedded as the finale)

**Every step is skippable.** Skipping marks the item ⚠ in the checklist and shows its
consequence line (D7 copy table). Rationale: each grant has a fallback (share sheet,
manual reconnect, tap-to-copy), and after a denial the system dialog often cannot be
re-shown anyway — so a hard block would dead-end against a dialog that no longer
appears. The wizard nudges (consequence copy, primary-styled Allow vs. text-styled
Skip), never traps.

Finishing pairing on step 5 shows a live "Connected" confirmation — completing the
wizard means the app demonstrably works.

### D3 — Per-step mechanics

**Notifications** — request `POST_NOTIFICATIONS` (API 33+; older APIs auto-pass the
step). Verify via the platform permission check. If permanently denied, the button
becomes "Open settings" (`ACTION_APPLICATION_DETAILS_SETTINGS`).

**Photos** — request `READ_MEDIA_IMAGES` (pre-33: `READ_EXTERNAL_STORAGE`), then on
return call the observer plugin's `accessLevel()`:

- `full` → advance.
- `partial` (user picked "Select photos") → the step switches inline to a recovery
  state: copy explains that auto-push needs "Allow all" and that the system dialog can
  no longer offer it; single button opens app settings
  (`ACTION_APPLICATION_DETAILS_SETTINGS`); state re-checked in `onResume`.
- `denied` twice → same settings-deep-link treatment (dialog suppressed by the OS).

**Battery exemption** — fire `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (direct
grant dialog; manifest gains `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). Play-policy
restrictions on this intent are irrelevant — Play distribution is out of scope on this
map. Verify via `PowerManager.isIgnoringBatteryOptimizations`.

**Xiaomi setup** — D5.

**Pairing** — the existing discovery + code-entry flow, restyled as the wizard finale.
No behavioral change to pairing itself.

### D4 — Detection of MIUI

The Xiaomi step and checklist section appear when `Build.MANUFACTURER` equals
`Xiaomi` case-insensitively (covers Xiaomi/Redmi/Poco), exposed over a small method on
the existing clipboard plugin (application-context only, no new plugin). No
`ro.miui.*` sysprop reading — manufacturer is sufficient for the target devices and
needs no reflection.

### D5 — MIUI guide: checkable, self-reported items

Four items, each with an action button and an **"I did this" checkbox persisted in
settings storage** (the app cannot verify any of them; self-report is the honest
completion signal):

| Item | Action |
| --- | --- |
| Autostart | Open MIUI autostart manager (`miui.intent.action.OP_AUTO_START` / security-center component, with `ACTION_APPLICATION_DETAILS_SETTINGS` fallback if unresolvable) |
| Battery: No restrictions | Open the app's battery-saver page (MIUI power-keeper component, same fallback) |
| Lock in recents | No deep link exists — "How?" expands an illustrated instruction (open recents → long-press/pull down the Vidyut card → tap the lock) |
| Clipboard permission | `miui.intent.action.APP_PERM_EDITOR` with the package extra, app-details fallback — same intent as the reactive hint in `zero-tap-receive.md` D3 |

All MIUI component intents are community-sourced; execution wraps each launch in a
resolve-check with the app-details fallback and must verify on the real Poco device.

**Feedback loop:** a clipboard `SecurityException` (the D3 taxonomy in
`zero-tap-receive.md`) **un-checks** the Clipboard item and re-flags it ⚠ in the
checklist, in addition to the one-time hint notification specced there. Showing the
guide proactively at onboarding is exactly the proactive-setup mitigation #29
delegated here.

### D6 — Status model (shared by wizard, checklist, home banner)

One `SetupStatus` snapshot, recomputed on app resume and after every wizard step:

| Item | Source | States |
| --- | --- | --- |
| Notifications | permission check | ok / off |
| Photos | `accessLevel()` | full / partial / denied |
| Battery exemption | `isIgnoringBatteryOptimizations` | ok / off |
| MIUI items ×4 | self-reported flags | done / not done (MIUI only) |
| Paired | pairing repository | paired / not paired |

Checklist rows: live-verifiable items show real state; MIUI rows show self-reported
state with a "we can't check these for you" footnote. All-green is reachable on MIUI
via self-report — deliberate, for the motivational value of a completed list.

### D7 — Copy

| Step | Title | Body | CTA / Skip consequence |
| --- | --- | --- | --- |
| Notifications | "Stay in the loop" | "Vidyut shows a small ongoing notification while sync runs, and a quiet receipt when something arrives from your laptop." | Allow / "You won't see receipts when the laptop sends you things." |
| Photos | "Spot your screenshots" | "To send screenshots automatically, Vidyut needs access to **all** photos. Pick **Allow all** — with 'Select photos' it can't see new screenshots." | Allow access / "Screenshots won't send themselves — you can still share manually." |
| Photos (partial) | "Almost — one change needed" | "You picked 'Select photos', so new screenshots stay invisible to Vidyut. Switch to 'Allow all' in settings." | Open settings |
| Battery | "Keep the link alive" | "Android puts idle apps to sleep, which drops the connection to your laptop. Allow Vidyut to ignore battery optimizations so payloads arrive even when the screen is off." | Allow / "Sync may pause when the phone sleeps." |
| Xiaomi | "Xiaomi needs a little extra" | "MIUI closes background apps aggressively. These four switches keep Vidyut alive — we can't check them for you, so tick what you've done." | (per-item buttons) / "MIUI will likely kill sync in the background." |
| Pairing | "Connect to your laptop" | (existing pairing flow copy) | — |

Tone: short, concrete, no permission-jargon in titles. Exact strings may be polished
during execution; the *claims* in each body are load-bearing and must not be weakened
(especially "Allow all" on the photos step).

### D8 — Settings screen additions

`SettingsScreen` gains, above the existing toggles:

- **Auto-send screenshots** toggle — the map's locked pause switch, default **on**;
  flipping it sends the existing `serviceSyncCommand` so the service reconciles the
  observer (per `screenshot-observer.md` §6). Subtitle names the requirement: "Needs
  full photos access."
- **Setup status** row — opens the checklist, with a trailing summary chip
  (green check or "2 issues").

The existing receive-notification toggle's subtitle is updated for the
`zero-tap-receive.md` D4 carve-out: "Show a receipt when something arrives from the
laptop. Delivery-failure notices always show."

### D9 — Visual design

Flat Raspberry Pink throughout (`design/theme.dart`, `design/palette.dart`): white
grounds, flat mist/petal surfaces, 20px radii, pill buttons, Plus Jakarta Sans with
weight-800 tight-tracked titles. Wizard steps are full-screen with a step-dots
indicator, `Entrance`-staggered content, raspberry pill primary CTA and muted text
Skip. Checklist rows are flat cards with status glyphs (raspberry check / muted
circle / error-tinted warning). No new design vocabulary.

## Acceptance criteria (for the execution effort)

1. Fresh install: wizard runs once, in D2 order; the Xiaomi step appears on the Poco
   and not on a stock-Android device; finishing pairing lands on a "Connected" state
   and sets `onboardingComplete`.
2. Every step skippable; each skip produces the ⚠ checklist state and consequence copy.
3. "Select photos" chosen on the system sheet → the wizard step flips to the partial
   recovery state, and after switching to "Allow all" in settings and returning, the
   step auto-advances.
4. Checklist reflects live state after external changes (revoke photos in system
   settings → row goes ⚠ on resume; home banner appears while auto-push is on).
5. All four MIUI deep-links either open the intended MIUI screen or fall back to
   app-details without crashing (verified on the real device).
6. A forced clipboard `SecurityException` un-checks the MIUI Clipboard item.
7. Settings shows the auto-push toggle (default on) and Setup status row; toggling
   auto-push reconciles the observer via `serviceSyncCommand`.

## Out of scope here

- Which persistent-notification buttons / in-app screens survive — the
  notification-surface simplification fog item (needs #28 too).
- Keepalive/reconnect behavior the battery exemption protects — #24.
- Measuring whether the MIUI toggles actually keep the process alive — #26.
