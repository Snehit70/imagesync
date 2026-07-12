# Phone-to-laptop uses the Android share sheet, not background auto-copy

Android 10+ forbids apps from reading the clipboard while in the background;
only the foreground app or active keyboard can. So a true "copy on phone →
appears on laptop" background flow is impossible without an accessibility
service, a custom IME, or root — all of which are fragile, permission-scary, or
heavy.

We accept the OS constraint instead of fighting it:

- **Phone → laptop:** the user taps *Share → Vidyut* on the content (one tap).
  This is the only path the OS reliably allows, and it needs no scary permissions.
- **Laptop → phone:** the incoming payload fires a notification; tapping it brings
  the app foreground and loads the payload into the clipboard, ready to paste.

The trade-off: phone→laptop is one deliberate tap, not automatic-on-copy. This is
a constraint of the platform, not a design preference — do not "fix" it with a
background clipboard watcher; it will be killed or rejected.
