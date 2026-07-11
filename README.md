# ImageSync

ImageSync is a LAN-only, end-to-end-encrypted clipboard pool for a Linux/Wayland laptop
and an Android phone: copy a screenshot or text on one device, paste it on the other a
second later. Same WiFi only; nothing ever touches the internet.

Two components: a **Bun relay** on the laptop (encrypted WebSocket protocol,
latest-write-wins pool, Wayland clipboard adapter/sync, mDNS advertisement, QR/manual
pairing, structured logs, compiled binary) and a **Flutter Android app** in `app/`
(share-sheet push, screenshot auto-push, zero-tap receive, foreground-service connection,
buttonless status dashboard). Two-direction sync is verified on-device; the live status
map is `docs/IMPLEMENTATION_STATUS.md` and the wayfinder map is GitHub issue #9.

## Guides

- **[docs/SETUP.md](docs/SETUP.md)** — new-user setup, laptop + phone, end to end.
- **[docs/USAGE.md](docs/USAGE.md)** — how to use it day to day.
- **[docs/INSTALL.md](docs/INSTALL.md)** — laptop relay install/service detail.
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — field-verified fixes.

The rest of this file is the developer-facing quickstart.

## Relay Prerequisites

- Linux Wayland session
- `wl-clipboard` installed (`wl-copy` and `wl-paste`)
- Bun 1.3.3 for development

## Run The Relay

```bash
bun install
bun run build:relay
./dist/imagesync-relay --log-level info
```

On first run the relay creates `~/.config/imagesync/relay.json` with a persistent pairing secret, prints a QR code, and prints the manual fallback:

```text
host=<lan-ip> port=17321 secret=<pairing-secret>
```

The relay checks whether the configured port is already in use before starting. It also advertises `_imagesync._tcp` over mDNS for phone discovery.

## Install As A Service

To run the relay persistently as a `systemd --user` service:

```bash
bun run install:relay
```

See `docs/INSTALL.md` for prerequisites, pairing under systemd, and troubleshooting.

## Development Checks

```bash
bun run typecheck
bun test
bun run build:relay
```

## Current Manual Relay Smoke Test

This verifies the laptop relay surface only. Full phone E2E requires the Android app.

```bash
./dist/imagesync-relay --no-clipboard --port 17321 --log-level debug
```

In another terminal, run the Bun tests against the in-process relay implementation:

```bash
bun test tests/relay-protocol.test.ts
```

## Full V1 E2E

The two-direction acceptance script — laptop text/image to phone via notification tap, phone share-sheet to laptop `wl-paste`, plus reconnect and observability checks — lives in `docs/E2E.md`. V1 is done when that script passes green in both directions on the real phone and laptop.
