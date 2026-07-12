# LAN-only relay hosted on the laptop

Vidyut syncs the clipboard pool only between devices on the same WiFi network,
via a small relay that runs on the laptop. Nothing leaves the LAN.

We deliberately rejected the cross-network alternatives:

- **VPS + public relay** — recurring cost and ops for a personal tool.
- **Tailscale + laptop relay** — too much per-user setup friction; the goal is
  "fast to set up and hand to a friend," and Tailscale is not that.
- **Nostr (public relays)** — free and cross-network, but public relays reject
  events over ~256 KB, so screenshots (0.5–5 MB) don't fit without a blob-server
  side-channel; that complexity is wrong for a first version.

The accepted trade-off: no sync when the two devices are on different networks,
and the laptop must be awake. In exchange we get zero infra, zero accounts,
zero cost, and the fastest possible setup — which is what makes the tool
shareable.
