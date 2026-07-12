# Vidyut (Flutter app)

The Android side of Vidyut — see the [repo root README](../README.md) for what
Vidyut is, and [`docs/SETUP.md`](../docs/SETUP.md) for the new-user setup guide.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
# output: build/app/outputs/flutter-apk/app-debug.apk
```

CI pins Flutter `3.44.4` (`stable` channel) — see `.github/workflows/ci.yml`.
Install Flutter via the [official install guide](https://docs.flutter.dev/get-started/install)
if you don't already have it.

The design source of truth is `lib/src/design/` (`palette.dart`, `theme.dart`,
`motion.dart`, `widgets.dart`); the local plugins in `packages/` (`vidyut_clipboard`,
`screenshot_observer`, `clipboard_autosend`) host the native Android channels.
