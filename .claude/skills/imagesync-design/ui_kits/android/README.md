# ImageSync Android UI Kit

Interactive recreation of the ImageSync Android app (Flutter, Material 3, "Flat Raspberry Pink" theme). Source of truth: `app/lib/src/` in https://github.com/Snehit70/imagesync.

Screens (click through in `index.html`, phone-sized 390×844):

- **Onboarding wizard** — step dots, blob permission steps (notifications / photos / battery), pairing finale with connected confirmation. From `onboarding/onboarding_wizard.dart`.
- **Home / pairing** — status hero (blob + status word), setup banner, nearby relays, manual pairing form; paired state with Reset pairing. From `main.dart`.
- **Settings** — switch cards + setup status row with issue chip. From `settings/settings_screen.dart`.
- **Setup status** — live checklist rows. From `onboarding/setup_checklist_screen.dart`.
- **Send clipboard** — success orb (ripple rings + blob). From `foreground/send_clipboard_screen.dart`.
- **Debug log** — timestamped category rows. From `debug/debug_log_screen.dart`.

Not recreated: QR scanner camera view (system camera surface).
