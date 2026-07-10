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

## Laptop: did the payload even arrive? The relay logs nothing

Until the observability work package (WP1, `docs/specs/relay-observability.md`)
lands, the relay logs nothing after startup — no connect/auth/payload events.
Interim diagnosis tools:

- Live socket check: `ss -tn state established '( sport = :17321 )'`
- Reconnect cadence monitor: loop `ss` output and log changes (see ticket #26
  resolution for the script).
- Laptop clipboard content: `wl-paste --list-types` and `wl-paste | head -c 200`.
