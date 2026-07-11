# "Forget this laptop" lives in Settings, behind a confirmation

The action formerly called **Reset pairing** is renamed **Forget this laptop**
and has exactly one entry point: a row at the bottom of Settings, guarded by a
confirmation dialog that states the consequence (the pairing is deleted and the
laptop must be re-paired via QR or manual entry).

Two problems drove this. Placement: it was a full-width filled CTA on the
paired home *and* an app-bar icon — the most prominent tap targets in the app
for its most destructive action — and neither asked for confirmation.
Naming: "reset" reads as a fix ("reset the connection"), inviting exactly the
wrong tap from someone whose sync is misbehaving; what the action actually does
is forget the laptop.

Rejected alternatives:

- **Keep an app-bar icon with a confirmation** — still advertises a destructive
  action on the happy-path screen.
- **Demote to a muted text button on home** — better, but home is a dashboard
  (ADR 0004); rare-and-dangerous belongs with rare-and-deliberate, which is
  Settings.
- **Keep the name "Reset pairing"** — established in code and docs, but the
  doc churn is a one-time cost and the wrong name misleads forever. "Forget
  this laptop" matches the Bluetooth "Forget device" pattern users already
  fear correctly.

The accepted trade-off: genuinely wanting to unpair now takes three taps
instead of one. That is the correct price for an action whose accidental cost
is re-scanning a QR code on another machine.
