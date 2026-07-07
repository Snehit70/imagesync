# ImageSync Implementation Status

This file is a live gap map against `docs/PRD.md`. It is not a replacement for the PRD.

## Implemented And Verified

- Relay WebSocket authentication rejects wrong pairing secrets.
- Relay broadcasts encrypted payload frames to paired devices.
- Late joiners receive the current pool payload.
- Latest timestamp wins; older payloads do not replace newer payloads.
- Oversized encrypted payloads fail with a clear protocol error.
- AES-256-GCM encrypt/decrypt works for payload frames; wrong key and tampered metadata fail.
- Wayland clipboard read/write/watch is behind a fakeable process boundary.
- Local clipboard changes publish encrypted payloads into the pool.
- Incoming remote payloads decrypt and write into the laptop clipboard.
- Relay config persists pairing secret, port, max payload size, device ID, and log level.
- Relay CLI prints QR plus manual pairing details.
- Relay advertises `_imagesync._tcp` through mDNS.
- Relay compiles into `dist/imagesync-relay`.
- Flutter Android app exists and builds a debug APK.
- Android QR/manual pairing UI stores relay host, port, and pairing secret in secure storage.
- Android WebSocket client authenticates with the same pairing proof as the relay.
- Android app is registered as a system share target for `text/plain` and `image/*`.
- Android share intake maps incoming text/image shares and publishes encrypted payloads after relay auth.
- Android app has a settings screen with persisted notification preferences.
- Incoming payload notifications can be disabled from the app settings.
- Android foreground notification service runs while paired when the send-notification setting is enabled.
- The foreground notification exposes a `Send clipboard` action that launches a focused clipboard-send flow.
- GitHub issues #1-#8 track the PRD and vertical implementation slices.

## Not Done

- Android notification tap to clipboard write.
- Android foreground WebSocket receive service. The current foreground service is notification-only and does not yet own the relay connection.
- Android mDNS relay discovery UI.
- Android image clipboard write path. `super_clipboard` was removed because its current Gradle/CargoKit path failed against this Flutter/Gradle stack.
- Android in-app logs/debug view.
- Cross-language Dart/TypeScript crypto fixtures.
- Debug APK CI artifact.
- Full two-direction manual E2E script.
- Green full D1-D9 completion audit.
- Physical-phone install/E2E is blocked by the connected MIUI device policy `INSTALL_FAILED_USER_RESTRICTED` until "Install via USB" is enabled on the phone.

## Latest Verified Commands

```bash
bun run typecheck
bun test
bun run build:relay
./dist/imagesync-relay --help
cd app && flutter test
cd app && flutter analyze
cd app && flutter build apk --debug
```
