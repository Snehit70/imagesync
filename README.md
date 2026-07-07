# ImageSync

ImageSync is a LAN-only clipboard pool for a Linux/Wayland laptop and an Android phone. The current implementation has the Bun relay slice: encrypted WebSocket protocol, latest-write-wins pool, Wayland clipboard adapter/sync, mDNS advertisement, QR/manual pairing output, structured logs, tests, and a compiled relay binary.

The Flutter Android app is not implemented yet. Track the remaining slices in GitHub issues #4-#8.

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

## Full V1 E2E Target

The final PRD target remains:

- Laptop screenshot or copied text automatically publishes to the pool.
- Phone receives a notification, and tapping it writes the payload to Android clipboard.
- Phone share-sheet push publishes image/text into ImageSync.
- Laptop clipboard receives the phone payload automatically.
- The app includes a settings screen for notification preferences.
- When enabled in settings, the app keeps a persistent foreground notification with a `Send clipboard` action for phone text.

That is not complete until the Flutter app, cross-language crypto fixtures, debug APK CI artifact, and manual two-direction E2E script are implemented.
