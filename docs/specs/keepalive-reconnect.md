# Keepalive and reconnect spec

Resolves [#24 Keepalive and reconnect spec: keep the socket warm through idle](https://github.com/Snehit70/vidyut/issues/24)
on the [Seamless Sync map](https://github.com/Snehit70/vidyut/issues/23).

## Goal

Keep the phone's relay socket warm through idle and make both ends detect a dead
path fast, against the map's bar: **≤2s device-to-device while the screen is on;
delivery by next reconnect/wake while dozing**.

## Grounding

- **Phone-survival measurements ([#26](https://github.com/Snehit70/vidyut/issues/26)):**
  the failure mode is **freeze, not flap**. MIUI froze the whole app process after
  28 idle minutes at baseline (no self-recovery possible — a frozen process runs no
  timers); after lock-in-recents + hibernation off, the same socket survived 67+
  minutes with zero drops. Implications: the relay-side reap is the *only* reliable
  frozen-phone detector; phone-side keepalive tunes drop *detection* and path
  warmth, it cannot fix freeze *recovery*; the steady state is a long-lived healthy
  socket, so modest cadence suffices.
- **Research** (`docs/research/android-seamless-sync.md` Q4): relay pings every 30s
  and reaps at 90s (`src/relay/relay.ts:15-16`), but the phone sends nothing, so a
  suspended/dropped path looks alive to the phone until the OS tears it down.
  Mature-app app-level keepalive range is 30–90s (relay 30s, Syncthing BEP 90s;
  KDE Connect uses TCP keepalive + 10s read timeout on raw sockets).

## Decisions

### D1 — Mechanism: WebSocket protocol-level pings; no wire-protocol change

The phone adopts `dart:io`'s built-in `pingInterval` by switching
`WebSocketRelayTransport.connect` (`app/lib/src/shared/relay_connection.dart:44`)
from `WebSocketChannel.connect` to `IOWebSocketChannel.connect` (same
`web_socket_channel` package; `dart:io`-only is fine for an Android-only app).

- Protocol pings are RFC 6455 **control frames**, not messages: they never reach
  the relay's `message` handler, so the publish-only restriction
  (`src/relay/relay.ts:97-100`) does not apply. The app-level ping the ticket
  flagged as needing a protocol change is unnecessary.
- Bun's server auto-responds to pings with pongs (RFC-required), so the phone's
  liveness check works against the relay as-is.
- `dart:io` semantics: a ping unanswered within `pingInterval` closes the socket
  (`goingAway`, 1001) → the existing `onDone` → offline → backoff path fires.
  One knob buys both keepalive traffic and phone-side death detection.

**Rejected:**

- *App-level ping wire message* — needs a new wire kind, a relay allowance, and
  client handling, for zero capability beyond what protocol pings give.
- *TCP keepalive (KDE Connect's approach)* — `dart:io`'s `WebSocket` does not
  expose the underlying socket for `setOption`, kernel default keepalive is ~2h,
  and the WS ping subsumes it.

### D2 — Intervals

| Knob | Value | Rationale |
|---|---|---|
| Phone `pingInterval` | **30s** | Mirrors the relay; inside the 30–90s mature range. Worst-case phone-side dead-path detection ≈60s (interval + timeout). Interleaved with the relay's own 30s pings, the idle socket carries traffic in each direction, keeping MIUI Wi-Fi power-save and any NAT state warm. Battery cost is negligible: the FGS wake lock already holds the process, and frames are tiny LAN traffic. |
| Relay heartbeat | **30s ping / 90s reap — unchanged** | #26: the reap is the sole frozen-phone detector; 90s = 3 missed pings. Against the "next reconnect/wake" doze bar, faster reaping buys nothing and risks reaping through momentary Wi-Fi power-save latency. |
| Relay `ping` handler | **add** (small change) | Wire Bun's `ping(ws)` websocket callback to refresh `lastSeen`, so inbound phone pings also count as liveness. Reap accuracy then no longer depends solely on the relay's outbound ping → pong round-trip. |

### D3 — Connect timeout: 5s

`IOWebSocketChannel.connect(..., connectTimeout: Duration(seconds: 5))` — matching
`SharePublisher.connectionTimeout`. Today a connect into a black hole (laptop
asleep, phone on another network) hangs at the OS SYN-retry cadence for minutes
with the controller stuck "searching"; the timeout fails it into the backoff loop.

### D4 — Backoff retune: cap at 32s

Keep the existing curve shape but drop the final 60s entry:
`[2, 4, 8, 16, 32]`, staying at 32s
(`app/lib/src/foreground/service_relay_controller.dart:20-27`). Steady-state drops
are rare after the #26 toggles, so backoff only climbs during genuine outages or
doze; halving the cap halves worst-case screen-on staleness while an idle retry
every ~32s on LAN costs nothing. Attempt reset on successful connect and on manual
sync stays as-is.

### D5 — Screen-on reconnect trigger

Register an `ACTION_SCREEN_ON` `BroadcastReceiver` in the service engine — hosted
by the same app-local plugin mechanism the zero-tap receive spec establishes
(`docs/specs/zero-tap-receive.md`) — that delivers a `sync`-equivalent to
`ServiceRelayController`: reset the attempt counter and reconnect immediately if
not connected (no-op when connected).

This is the piece that actually meets the ≤2s screen-on bar in the recovery case:
after doze *without* battery exemption, the network was suspended, the phone's
pings failed, the socket closed, and backoff retries kept failing at the 32s cap.
The user wakes the phone and screenshots immediately — without the trigger,
reconnect can lag up to 32s; with it, reconnect + auth is ~1 LAN round-trip
(well under 1s), after which the auto-push spec's offline hold republishes.
The freeze case needs no trigger (unfreezing fires expired Dart timers
immediately), but the receiver is nearly free and covers the
not-frozen-but-disconnected case.

### D6 — Laptop leg unchanged

`clipboard-sync`'s client talks to the relay over localhost and auto-pongs the
relay's pings; warmth, NAT, and doze don't apply. Its lack of reconnect logic is
a v1-map concern, out of scope here.

### D7 — Close observability

The phone's `RelayEvent('Relay socket closed.')` gains the close code and reason
(`closeCode`/`closeReason` from the channel), so a 1001 ping-timeout close is
distinguishable from a relay-initiated close in the debug log. Relay-side
attribution comes from the observability spec's `device_disconnected`
(`wsCode`/`wsReason`) vs `socket_reaped` (`idleMs`) split.

## Measuring the bar

- **Screen-on ≤2s:** phone debug-log line at the screen-on trigger →
  relay `auth_ok{connId}` (observability spec); assert ≤2s between them. Payload
  latency itself is covered by `clipboard_write.e2eMs` and the auto-push spec's
  `captureToDetectMs` + `e2eMs`.
- **Idle survival:** repeat #26's method (laptop-side socket monitor, ≥60 min
  screen-off, MIUI toggles applied) with keepalive in place, reading
  `device_connected` / `device_disconnected` / `socket_reaped` gaps. Acceptance:
  zero `socket_reaped` events; every drop attributable via `wsCode`/`idleMs`.

## Contingency (closes the map's escalation fog)

#26 measured zero kills over 67+ minutes once lock-in-recents was applied, so no
escalation mechanism (e.g. a periodic WorkManager nudge) enters this plan. If
execution-time measurement contradicts that — reaps recurring despite toggles +
battery exemption + keepalive — the first lever is the unexplored MIUI
**Autostart** toggle, then a WorkManager nudge as a fresh effort. That is a
decision deferred on evidence, not one left open.

## Change summary

- **App:** `IOWebSocketChannel.connect(uri, pingInterval: 30s, connectTimeout: 5s)`;
  backoff `[2, 4, 8, 16, 32]`; screen-on receiver → sync command; close
  code/reason in the socket-closed debug event.
- **Relay:** add `ping(ws)` handler updating `lastSeen`; heartbeat constants
  unchanged.
