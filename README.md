# ImageSync

ImageSync is a LAN-only clipboard pool for a Linux/Wayland laptop and an Android phone. The current implementation has the Bun relay slice: encrypted WebSocket protocol, latest-write-wins pool, Wayland clipboard adapter/sync, mDNS advertisement, QR/manual pairing output, structured logs, tests, and a compiled relay binary.

The Flutter Android app lives in `app/`. Remaining work is tracked on the wayfinder map, GitHub issue #9; the live gap list is `docs/IMPLEMENTATION_STATUS.md`.

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
