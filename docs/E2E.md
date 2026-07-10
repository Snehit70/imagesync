# Manual Two-Direction E2E Script

This is the acceptance script for ImageSync v1: laptop ↔ phone clipboard sync verified in both directions on real hardware. Run every step in order; the run is **green** only if every ✅ checkpoint passes.

Hardware: the Linux/Wayland laptop running the relay and the Android phone, on the same WiFi.

## 0. Preconditions

On the laptop:

```bash
systemctl --user status imagesync-relay        # active (running)
journalctl --user -u imagesync-relay -b --no-pager | tail -40   # QR + manual pairing line
```

If the relay is not installed yet, run `bun run install:relay` from the repo root (see `docs/INSTALL.md`).

On the phone:

- Install the debug APK: `adb install -r app/build/app/outputs/flutter-apk/app-debug.apk` (build with `cd app && flutter build apk --debug`).
- MIUI: Settings → Battery → ImageSync → **No restrictions**, so the foreground service survives backgrounding.
- Phone and laptop on the same WiFi network.

## 1. Pairing

1. Open ImageSync on the phone.
2. The pairing screen should list the relay discovered over mDNS (`_imagesync._tcp`). Tap it — host/port fill in; enter only the secret from the journal line.
   - ✅ Relay appears in the discovery list without typing host/port.
   - Fallback: scan the QR from the journal, or type the full `host=… port=… secret=…` line manually.
3. Pair.
   - ✅ App shows **connected** status.
   - ✅ A persistent foreground notification appears showing connection status.
   - ✅ Relay journal logs the device authenticating.

## 2. Laptop → phone: text

1. On the laptop, copy a distinctive string:

   ```bash
   printf 'e2e-text-%s' "$(date +%s)" | wl-copy
   ```

2. On the phone (app backgrounded, screen on):
   - ✅ A notification arrives for the incoming text payload.
3. Tap the notification.
   - ✅ App foregrounds and copies the text.
4. Paste into any text field (e.g. a notes app).
   - ✅ Pasted text matches the string exactly.

## 3. Laptop → phone: image (screenshot)

1. Take a screenshot on the laptop and put it on the clipboard (Hyprland example):

   ```bash
   grim -g "$(slurp)" - | wl-copy --type image/png
   ```

2. On the phone:
   - ✅ Notification arrives for the incoming image payload.
3. Tap the notification.
   - ✅ App foregrounds and copies the image.
4. Paste into an image-accepting field (e.g. a messaging app compose box).
   - ✅ The screenshot pastes intact.

## 4. Phone → laptop: text

1. In any phone app, select text → Share → **ImageSync**.
2. On the laptop:

   ```bash
   wl-paste
   ```

   - ✅ Output matches the shared text exactly.

## 5. Phone → laptop: image

1. In the phone gallery, share a photo → **ImageSync**.
2. On the laptop:

   ```bash
   wl-paste --list-types          # should include image/png
   wl-paste --type image/png > /tmp/e2e-recv.png
   xdg-open /tmp/e2e-recv.png
   ```

   - ✅ The received image opens and matches the shared photo.

## 6. Reconnect resilience

1. Toggle WiFi **off** on the phone, wait ~15 seconds, toggle it back **on**.
   - ✅ Foreground notification shows disconnected, then reconnects on its own (backoff starts at 2s).
   - ✅ No duplicate notification for the payload already in the pool after re-auth.
2. Repeat step 2 (laptop → phone text) once after reconnecting.
   - ✅ Sync still works.

## 7. Observability spot-check

- Open the in-app debug log (bug icon in the app bar).
  - ✅ Entries show the connection, auth, payload (type/size/origin), and send events from this run.
- `journalctl --user -u imagesync-relay -f` during a sync.
  - ✅ Relay emits structured, timestamped, leveled log lines.

## Recording a run

Append a dated line to the table below after each full run.

| Date | APK commit | Result | Notes |
|------|-----------|--------|-------|
