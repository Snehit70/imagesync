# Settings is sectioned around a renamed master sync switch

Settings grows from five rows to roughly seven (screenshots toggle, receive-
notifications toggle, the master switch, setup status, Advanced, debug log,
Forget this laptop). At that size a flat list hides the one control that
matters most, so Settings gains section headers and a deliberate order:

1. **The master switch, first and alone at the top.** It is renamed from
   **Background sync** to **Sync with laptop**, because "background sync" reads
   as a notification preference while the switch actually governs *all* syncing —
   its own subtitle already admitted "Off stops all syncing." The new subtitle
   keeps that honesty: "Off disconnects and stops clipboard, screenshots, and
   receive." A control that turns the product off must be named and placed like
   one.
2. **Sync** — auto-send screenshots.
3. **Notifications** — receipts when laptop payloads arrive.
4. **Setup** — setup status row, Advanced (clipboard auto-send), debug log
   (moved here from the home app bar, per ADR 0004).
5. **Danger zone** — Forget this laptop (ADR 0005).

Rejected: a flat list ordered by weight with no headers (fits the flat
aesthetic but still buries the master switch's significance), and keeping the
current order (grouping felt like ceremony at five rows, but seven rows with a
destructive action at the bottom is exactly when grouping earns its keep).

The accepted trade-off: section headers are the first typographic hierarchy in
an otherwise header-light UI. They stay muted 600-weight labels so the flat,
calm surface language holds.
