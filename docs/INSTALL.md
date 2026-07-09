# Installing The Relay (Laptop)

The relay is a single compiled binary that runs on the Linux/Wayland laptop, watches the clipboard, and serves paired phones over the LAN. This guide installs it as a persistent `systemd --user` service.

## Prerequisites

- A **Wayland session** — the relay reads and writes the clipboard through `wl-copy`/`wl-paste`, so it does not work on X11 or headless machines.
- **wl-clipboard** — provides `wl-copy` and `wl-paste`:

  ```bash
  sudo dnf install wl-clipboard      # Fedora
  sudo apt install wl-clipboard      # Debian/Ubuntu
  ```

- **Bun** (build only) — the binary is compiled from source with [Bun](https://bun.sh). Once installed, the service does not need Bun.

## Quick Install

From the repo root:

```bash
bun run install:relay
```

This builds `dist/imagesync-relay`, installs it to `~/.local/bin/imagesync-relay`, installs the unit from `packaging/systemd/imagesync-relay.service` to `~/.config/systemd/user/`, and enables + starts the service.

The unit is tied to `graphical-session.target`, so the relay starts with your desktop session and stops when you log out.

## Pairing

On first start the relay creates `~/.config/imagesync/relay.json` (mode 600) with a persistent pairing secret, then prints a QR code and a manual fallback line:

```text
host=<lan-ip> port=17321 secret=<pairing-secret>
```

When running under systemd that output lands in the journal. To pair the phone:

```bash
journalctl --user -u imagesync-relay -b --no-pager | tail -40
```

Scan the QR code with the ImageSync app, or use the app's manual entry with the `host=... port=... secret=...` line. If the QR renders poorly in your terminal, widen the window or use manual entry — the secret never changes between restarts, so pairing once is enough.

Alternatively, pair before installing the service by running the binary directly once: `./dist/imagesync-relay`.

## Managing The Service

```bash
systemctl --user status imagesync-relay    # is it running?
journalctl --user -u imagesync-relay -f    # follow logs
systemctl --user restart imagesync-relay   # restart (e.g. after rebuilding)
systemctl --user disable --now imagesync-relay   # stop and disable
```

After pulling changes, re-run `bun run install:relay` to rebuild, reinstall, and restart in one step (re-enabling an enabled service is a no-op).

## Troubleshooting

- **`wl-copy` errors / clipboard not syncing**: the service can't see your Wayland display. GNOME and KDE import `WAYLAND_DISPLAY` into the systemd user environment automatically; on other compositors (e.g. sway) run `systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` from your session startup, then restart the service.
- **Port already in use**: the relay refuses to start if its port (default `17321`) is taken. Change `port` in `~/.config/imagesync/relay.json` and restart.
- **Phone can't discover the relay**: the relay advertises `_imagesync._tcp` over mDNS. Make sure the laptop firewall allows mDNS (UDP 5353) and the relay port on your LAN zone, and that both devices are on the same network.
