# Troubleshooting

Field-verified fixes from real debugging sessions on the owner's setup (Fedora +
Hyprland laptop, Xiaomi HyperOS phone). Symptom → cause → fix. Add new entries
as they are diagnosed; only record what was actually reproduced and fixed.

## Phone: tapping "Send clipboard" on the notification does nothing

**Symptom:** The notification button gives no visible reaction. Opening the app
manually afterwards fires the queued send immediately — so the tap clearly
*reached* the app.

**Cause:** Android 12+ blocks "notification trampolines": a service handling a
notification tap may not launch an activity. MIUI/HyperOS stacks its own
background-start gate on top. Verified in logcat at the moment of the tap:

```
NotificationService: Indirect notification activity start (trampoline)
                     from dev.snehit.imagesync.imagesync blocked
ActivityTaskManager: Abort background activity starts from 10388
```

**Fix (verified 2026-07-10):** the app must hold the **overlay permission**
(`SYSTEM_ALERT_WINDOW`) — it is on Android's exemption list for background
activity starts. Two parts:

1. The manifest must declare `android.permission.SYSTEM_ALERT_WINDOW`,
   otherwise the app never appears in the overlay-permission settings list and
   `adb shell appops set ... SYSTEM_ALERT_WINDOW allow` silently stays
   `default` on MIUI.
2. Grant it: Settings → Apps → ImageSync → "Display over other apps" → Allow
   (open the page directly with `adb shell am start -a
   android.settings.action.MANAGE_OVERLAY_PERMISSION -d
   package:dev.snehit.imagesync.imagesync`).

**Dead end, recorded to save the next hour:** MIUI's Other-permissions toggle
"Open new windows while running in the background" did **not** lift the block —
logcat showed the identical trampoline abort after enabling it. Only the
overlay grant flipped `allowBackgroundActivityStart`. Belongs in the
onboarding checklist (WP6).

**Diagnosis recipe:** `adb logcat -c`, tap the button, then
`adb logcat -d | grep -iE 'trampoline|Background activity'`.

## Phone: send screen says "Clipboard is empty" when launched from the notification

**Symptom:** Launching the send flow from the notification button reports an
empty clipboard even though Gboard's clipboard shows the copied text. Opening
the app first and navigating manually works.

**Cause:** Android 10+ only allows clipboard reads while the app's window has
*input focus*. On a cold launch from a notification the first frames render
before focus lands, so an immediate read comes back empty. (KDE Connect reads
in `onWindowFocusChanged(true)` for the same reason.)

**Fix:** Fixed in code — `SendClipboardScreen` retries the read (250ms × 10)
before concluding the clipboard is empty. If it regresses, check that the
retry loop in `app/lib/src/foreground/send_clipboard_screen.dart` still runs.

## Phone: connection silently dies after ~30 minutes idle and never recovers

**Symptom:** Relay socket to the phone goes dead ~28 minutes after the screen
turns off; the app's reconnect/backoff never fires; connection returns only
when the app is manually opened.

**Cause:** MIUI **freezes the entire app process** when idle — not just the
network. A frozen process can't run reconnect timers, so client-side recovery
logic is powerless. Measured 2026-07-10: kill at 28 idle minutes *despite*
Battery saver already set to "No restrictions".

**Fix:** **Lock the app in recents** (open recents, pull the ImageSync card
down until the padlock shows). This was the decisive lever: same socket
survived 67+ minutes with zero drops afterwards. Supporting toggles: Battery
saver "No restrictions", app hibernation ("Pause app activity if unused") off.
Full data: wayfinder ticket #26.

## Phone: notification button semantics (for future debugging)

The flutter_foreground_task plugin wires the notification **body** tap as a
direct activity PendingIntent (always works), but **buttons** as broadcasts to
the service (`ForegroundService.kt:580` in the plugin) — anything a button does
that needs UI must survive the background-activity-start rules above. If a
button flow breaks again on a new Android/MIUI version, suspect this first;
the quick-settings-tile approach (allowed to launch activities, what KDE
Connect uses) is the documented fallback.

## Laptop: relay changes don't show up after `systemctl --user restart`

**Symptom:** Rebuilt the relay (`bun run build:relay`), restarted the service,
but new behavior/log events don't appear.

**Cause:** The systemd unit runs `%h/.local/bin/imagesync-relay`, not the repo's
`dist/imagesync-relay`. A rebuild only updates `dist/`; restarting relaunches
the stale installed copy.

**Fix (verified 2026-07-10):** `install -m 755 dist/imagesync-relay
~/.local/bin/imagesync-relay` (or the full `bun run install:relay`), *then*
restart the service.

**Mirror trap (verified 2026-07-11):** `bun run install:relay` alone is not
enough either — the script ends with `systemctl --user enable --now`, which is
a no-op when the service is already running, so the old process keeps serving
the stale binary (check: the PID in `journalctl` output doesn't change). Always
follow an install with an explicit `systemctl --user restart imagesync-relay`.
The phone drops with wsCode 1006 and auto-reconnects within the backoff window.

## Held screenshot lost after the relay restarts (`payload_stale_dropped`)

**Symptom:** Phone holds a screenshot while the relay is down (`screenshot_held`
logged on the phone). After the relay restarts and the phone reconnects, the
image never reaches the laptop clipboard; the relay logs `payload_stale_dropped`
for it with `frameTs < currentTs`, and a `payload_broadcast{replay:true}`
carrying old content fired just before.

**Cause:** `wl-paste --watch` fires once immediately for the selection that
already exists at relay startup. The relay treated that startup fire as a real
change and re-published the current laptop clipboard with a fresh `now()`
timestamp. That phantom payload is newer than the held frame (stamped at
capture time during the outage), so the pool's `ts` stale-check drops the held
frame. Only bites when the relay itself restarts (laptop sleep/wake, crash,
reboot) — the exact case offline-hold covers.

**Fix (verified 2026-07-11):** the Wayland adapter (`src/relay/clipboard.ts`)
swallows the first `wl-paste --watch` fire; every later one is a real change.
Confirmed on-device: restart no longer re-publishes the clipboard, and a
screenshot held across a full relay stop/start now republishes and lands.

## Laptop: `clipboard_write` logs seconds after the payload arrived, acks stall

**Symptom:** A phone payload reaches the relay instantly (`payload_published`
with a small `relayLagMs`), but `clipboard_write` logs 10–20s later with a huge
`e2eMs`, and the phone's `screenshot_acked` shows the same `ackMs`. The
clipboard content itself is pasteable immediately.

**Cause:** `wl-copy` forks a daemon to serve the selection, and the daemon
inherits the stdout/stderr pipes. The relay's process runner waited for pipe
EOF, which only happens when the daemon **loses the selection** — so every
write resolved on the *next* clipboard change, stalling the ack and poisoning
the `e2eMs` metric. Reproduced standalone: the same spawn pattern hung 165s
and resolved the instant another `wl-copy` ran.

**Fix (verified 2026-07-11):** `detachOutput` in `src/relay/clipboard.ts` —
for `wl-copy` writes, await only the direct child's exit and never the pipes
(a failing wl-copy exits before forking, so stderr is still readable on
nonzero exit). Write latency went 165,543ms → 17ms on a 186KB image.

## Laptop: image is on the clipboard but Ctrl+V pastes nothing

**Symptom:** `wl-paste --list-types` shows the phone image arrived (relay
logged `clipboard_write`), local screenshots paste fine, but Ctrl+V of the
phone image does nothing in browsers/Electron apps.

**Cause:** Format, not delivery. MIUI screenshots arrive as `image/jpeg` (the
share-sheet path can even arrive as a non-concrete `image/*`), and most Linux
apps only accept `image/png` from the clipboard — they see a jpeg-only offer
and silently decline. Local screenshot tools always offer PNG, which is why
those paste.

**Fix (verified 2026-07-11):** the relay re-encodes any non-PNG image through
ImageMagick (`magick - png:-`) before the clipboard write and offers
`image/png`; `magick` sniffing the real format from the bytes also repairs the
`image/*` case. Missing/failing `magick` falls back to writing the raw bytes
(the old behavior). Conversion adds ~1s for a full phone screenshot — budget
this against the 2s screen-on bar. Requires `ImageMagick` installed on the
laptop.

## Laptop: did the payload even arrive? The relay logs nothing

Until the observability work package (WP1, `docs/specs/relay-observability.md`)
lands, the relay logs nothing after startup — no connect/auth/payload events.
Interim diagnosis tools:

- Live socket check: `ss -tn state established '( sport = :17321 )'`
- Reconnect cadence monitor: loop `ss` output and log changes (see ticket #26
  resolution for the script).
- Laptop clipboard content: `wl-paste --list-types` and `wl-paste | head -c 200`.
