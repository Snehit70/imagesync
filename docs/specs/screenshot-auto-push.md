# Spec: Screenshot auto-push pipeline — observer event to encrypted publish

Status: locked (resolves [#28](https://github.com/Snehit70/vidyut/issues/28)).
Research basis: `docs/research/android-seamless-sync.md` Q1/Q4.
Upstream: the [screenshot observer spec](screenshot-observer.md) ends at a screenshot event
delivered to the service isolate; this spec starts there and ends at the frame acked by the
relay. The laptop leg (broadcast → Wayland clipboard write) already exists in
`clipboard-sync.ts` and is instrumented by the
[relay observability spec](relay-observability.md); nothing on the laptop changes here.

## 1. Pipeline shape and ownership

**Decision: a long-lived `ScreenshotPushController` in the service isolate, owning a
single-slot latest-wins pending frame, attached to whichever `RelayConnection` is current.**

- New file `app/lib/src/push/screenshot_push_controller.dart`. Created once at service start
  (wired in `VidyutForegroundTaskHandler._relayController()` like the other collaborators)
  and injected into `ServiceRelayController`, mirroring how `receiverFactory` is injected —
  constructor-injected reader/crypto/clock so it stays unit-testable.
- `ServiceRelayController` is the integration point, not the implementation: `_sync()` calls
  `pushController.attachSession(connection)` after creating the connection, and `_teardown()`
  calls `detachSession()`. The controller is **long-lived across reconnects** — connections are
  torn down and rebuilt on every `_sync()`, and the pending frame must survive that (it is the
  offline hold, §6).
- The controller consumes the observer's event stream (the `vidyut/screenshot_events`
  EventChannel surfaced by the watcher from the observer spec §6), which only flows while the
  watcher runs — so the auto-push toggle (§7) gates the whole pipeline at the watcher.
- Everything runs in the service isolate. Nothing is forwarded to the UI isolate except debug
  log lines via the existing `emit({'kind': 'log', ...})` channel.

Publishing rides the **existing persistent socket** — `RelayConnection.publish` on the service's
connection. The `SharePublisher` ephemeral-session pattern (connect → publish → close) is
explicitly not reused: the service already holds an authenticated socket, and a second
connection per screenshot would pay connect+auth latency against the 2s bar for nothing.

## 2. Reading the bytes

**Decision: a `readImage` method on the existing observer plugin channel, with a short retry
for MIUI indexing lag.**

- `MethodChannel vidyut/screenshot_observer` gains `readImage(id)` → `Uint8List`:
  `contentResolver.openInputStream(ContentUris.withAppendedId(EXTERNAL_CONTENT_URI, id))`,
  read fully, return the bytes. Dart cannot open `content://` URIs; this stays in the plugin.
  The read runs on the plugin's existing observer `HandlerThread` (never the main thread), and
  the result posts back to the platform thread for channel delivery. `StandardMessageCodec`
  moves `ByteArray`/`Uint8List` without base64 inflation, so a multi-MB screenshot over the
  channel is one copy, not an encoding round-trip.
- Errors: `not-found` (row or file gone — deleted before we read, or MediaStore still settling)
  and `io-error`. **Retry policy:** 3 attempts total, 300ms apart, on either error — the
  observer's query already excludes `IS_PENDING=1` rows so the file is normally complete when
  the event fires, but MIUI's scanner has been observed to publish rows ahead of stable reads
  (research Q1). After the third failure the screenshot is skipped with
  `screenshot_skipped{reason: read_failed}` — the share sheet remains the fallback.
- **Size guard before reading:** the event's `sizeBytes` is checked against the cap (§3) so an
  oversized file is never pulled through the channel. `sizeBytes` can be 0/absent while MIUI
  is still indexing; a 0 means read anyway and re-check the actual byte length after.

## 3. Payload format and size policy

**Decision: passthrough — publish the screenshot file bytes as-is, no downscale, no
recompression.**

- `type: "image"`, `mime` passed through from the observer event (`image/png` on both target
  devices; whatever MediaStore reports otherwise). The laptop leg is already mime-generic.
- Rationale: screenshots on the target devices (1080×2400 class) are ~0.5–3MB PNGs; even QHD
  worst cases sit under ~10MB. The relay cap defaults to 25MiB (`defaultMaxPayloadBytes`,
  measured on the decoded ciphertext = plaintext + 16-byte GCM tag). Recompression would burn
  hundreds of ms of CPU against the 2s bar and degrade the artifact to protect headroom that
  is never used. If a device someday produces screenshots near the cap, downscaling becomes a
  new decision — accepted limit (§9), not built now.
- **Cap check:** skip (never truncate) when `plaintextBytes + 16 > cap`, logging
  `screenshot_skipped{reason: too_large}`. The cap is the relay's advertised
  `hello.maxPayloadBytes`; `RelayConnection` currently discards that field and must **capture
  and expose it** (nullable until the hello arrives; fall back to the 25MiB constant mirrored
  from the relay default).

## 4. Frame semantics and encryption

- `origin: "phone"` — the service's `deviceId`, so `_shouldHandleFrame` drops the relay's
  post-auth replay of our own frame on reconnect, as it already does today.
- **`ts = detectedAtEpochMillis`** from the observer event — *detection* time, not
  `DATE_ADDED`. Two reasons it beats capture time: (a) the pool's latest-wins compare needs
  millisecond precision and rough monotonicity, and `DATE_ADDED` is floor-to-second — a
  screenshot could stamp *earlier* than a clipboard payload published between capture and
  detection and be wrongly stale-dropped; (b) it makes the relay's `e2eMs` a clean
  detect→laptop-clipboard measurement, with the capture→detect half logged phone-side by the
  observer spec (§8 below reconciles the two into the bar). Monotonic guard: if a frame's `ts`
  would be ≤ the last published frame's `ts` (burst rows can share a detection millisecond),
  bump it by +1ms.
- Encrypt via the existing `PayloadCrypto` (AES-GCM, same AAD scheme as every other payload).
  No wire or contract changes: the frame is a standard v1 `publish`.

**Crypto cost decisions (both bite the 2s budget):**

1. **Memoize the derived key.** `PayloadCrypto._deriveKey` runs PBKDF2 at 200k iterations on
   *every* encrypt and decrypt — pure waste after the first call since the pairing secret is
   fixed. Cache the `SecretKey` per pairing secret inside `PayloadCrypto`. This also speeds up
   every receive.
2. **Enable `cryptography_flutter`** so `package:cryptography` delegates AES-GCM and PBKDF2 to
   platform crypto instead of pure Dart — a drop-in (`FlutterCryptography.enable()`), and as a
   plugin it auto-registers in the service engine like the observer/clipboard plugins.
   Execution must verify via the §8 timing logs that the native path is actually taken in the
   headless engine; the package silently falls back to Dart if the channel is missing, which
   is correct but slow.

## 5. Burst handling: latest wins end to end

The pool keeps only the newest payload, so the pipeline mirrors that semantic at every stage —
**a single-slot, latest-wins pipeline; no queue**:

- Events are processed one at a time. If a newer screenshot event arrives while an older one is
  still being read/encrypted, the newer one waits in a depth-1 slot and any event it displaces
  is dropped with `screenshot_skipped{reason: superseded}`. When the in-progress item finishes
  encrypting and a newer event is waiting, the finished frame is *not* published — superseded.
- The **pending slot** (§6) holds at most one encrypted frame — the newest. Writing a newer
  frame into it discards the older unacked one.
- Multiple rows surviving one observer query (a true burst) resolve by the same rule: the
  newest row (`DATE_ADDED`, then `id`) wins the slot; earlier ones may still publish if they
  complete first, and the pool's `ts` compare guarantees the newest ends up as the pool
  payload either way.

## 6. Publish, ack, and offline hold

**Decision: hold the latest frame while disconnected and publish on reconnect; clear the slot
only on relay ack.**

- After encrypt, the frame enters the pending slot. If the session status is `connected`, it
  is sent immediately (`screenshot_publish`); otherwise it is held (`screenshot_held`) — this
  is the map's "delivery by next reconnect/wake while dozing" behavior: Doze kills the socket,
  the frame waits in the slot, `ServiceRelayController`'s existing backoff reconnects on wake,
  and attach + the `connected` status transition republishes.
- **Ack handling:** the relay already answers every accepted publish with
  `{kind: "ack", ts}`; `RelayConnection._handleMessage` currently ignores it. It must surface
  acks (a `Stream<int>` of acked `ts`). The pending slot clears when an ack's `ts` matches the
  slot's frame. An unacked frame is re-sent **verbatim** on the next `connected` transition —
  same nonce/ciphertext, which is cryptographically fine (identical bytes, no nonce reuse with
  new plaintext) and idempotent at the pool (equal `ts` re-accepts and re-broadcasts; the
  laptop rewrites the same image).
- **`payload_too_large` guard:** the §3 pre-check makes this unreachable in normal operation,
  but if the relay still rejects (cap lowered between hold and reconnect), the pending frame
  must be **dropped** on that error code — otherwise the existing error→offline→reconnect
  behavior in `RelayConnection` would republish the same rejected frame in a loop.
- **No persistence.** The slot is in-memory; a service restart loses it. This matches the
  observer spec's watermark decision — screenshots from before the current service session are
  never auto-pushed; the share sheet covers them.

## 7. Settings toggle

- New `AppSettings` field **`autoPushScreenshots`, default `true`** (always-on while the
  service runs, per the map's locked decision), persisted alongside the existing settings and
  surfaced in the settings screen as "Auto-push screenshots".
- What it gates: the **watcher**, per the observer spec §6 — toggle flip → UI sends the
  existing `serviceSyncCommand` → `_sync()` starts/stops the watcher. No watcher, no events,
  no pipeline. Toggling **off also clears the pending slot** (a held frame must not surface
  minutes later when the user has said stop). It does not affect share-sheet or Send-clipboard
  paths.
- Permission interaction is the observer spec's §5 contract: setting on + access not `full`
  → watcher refuses and the paused state surfaces; the pipeline itself never checks
  permissions.

## 8. Instrumentation and measuring the ≤2s bar

Phone-side events through the existing debug log (service isolate → `emit` → debug log),
naming aligned with the relay observability spec:

| Event | Fields | Emitted |
|---|---|---|
| `screenshot_read` | `id`, `bytes`, `readMs`, `attempts` | bytes in hand |
| `screenshot_encrypted` | `nonce`, `ts`, `plaintextBytes`, `encryptMs` | frame built |
| `screenshot_publish` | `nonce`, `ts`, `bytes`, `sinceDetectMs` | frame sent on the socket |
| `screenshot_held` | `nonce`, `ts` | encrypted while disconnected |
| `screenshot_republished` | `nonce`, `ts`, `heldForMs` | pending re-sent after reconnect |
| `screenshot_acked` | `ts`, `ackMs` (send→ack) | ack matched the pending slot |
| `screenshot_skipped` | `id`, `reason: too_large \| read_failed \| superseded` | any drop |

The observer spec (§7) already logs detection: `captureToDetectMs` ≈ `detectedAtEpochMillis −
DATE_ADDED×1000` (±1s, `DATE_ADDED` is seconds-coarse). The relay's `clipboard_write.e2eMs`
(observability spec) measures `frameTs` → laptop clipboard, and since this spec sets
`frameTs = detectedAtEpochMillis`:

> **Bar measurement (screen-on): `captureToDetectMs` (phone log) + `e2eMs` (relay log) ≤ 2000ms
> per screenshot.**

This refines the observability spec's "frameTs is origin capture time" for screenshot frames:
capture→detect is deliberately excluded from `frameTs` (ordering correctness, §4) and accounted
for by the phone-side term instead. Doze delivery is measured exactly as the observability spec
already defines (`recipients: 0` → reconnect → replay), with `screenshot_held`/
`screenshot_republished.heldForMs` giving the phone-side view of the same gap.

## 9. Known limits (accepted)

- A screenshot held while offline is lost if the service dies before reconnect (in-memory
  slot; consistent with the no-catch-up watermark). Share sheet recovers it manually.
- Only the newest of a burst is guaranteed to reach the laptop clipboard — by design, the pool
  itself has no history.
- No downscale/recompress path: a screenshot exceeding the relay cap is skipped, not shrunk.
  Not reachable on target devices; revisit only if a real device produces >25MiB screenshots.
- `captureToDetectMs` is ±1s coarse; the bar verdict on a set-up device uses many samples, not
  one.

## Acceptance criteria (for the execution effort)

1. Screen on, connected, app backgrounded: a screenshot lands on the laptop clipboard with
   zero taps; `captureToDetectMs + e2eMs ≤ 2000` on the instrumented run (median over ≥10
   samples on the set-up Poco device).
2. Burst: five rapid screenshots produce the newest one as the laptop clipboard content; no
   crash, and skipped ones log `superseded`.
3. Offline hold: screenshot taken with relay down → `screenshot_held`; relay restarted →
   frame arrives with `screenshot_republished` and lands on the laptop clipboard.
4. Doze: screenshot while dozing (socket dead) → delivered on next reconnect/wake, visible as
   the observability spec's replay signature plus `heldForMs`.
5. Ack discipline: every delivered screenshot logs `screenshot_acked`; killing the relay
   between publish and ack, then restarting, re-delivers the same frame exactly once.
6. Toggle: "Auto-push screenshots" off stops the watcher, clears any pending frame, and no
   publish occurs; on re-enables without service restart.
7. `screenshot_encrypted.encryptMs` on-device confirms native crypto (order-of-magnitude drop
   vs. pure Dart) and key memoization (first call slow, subsequent calls fast).

## Out of scope here

- Permission UX and MIUI setup screens — onboarding spec ([#30](https://github.com/Snehit70/vidyut/issues/30)).
- Socket keepalive/reconnect cadence that determines *when* a held frame gets its reconnect —
  keepalive spec ([#24](https://github.com/Snehit70/vidyut/issues/24)) and survival
  measurements ([#26](https://github.com/Snehit70/vidyut/issues/26)).
- Which notification buttons/screens remain after zero-tap lands — the notification-surface
  ticket graduated by this spec.
