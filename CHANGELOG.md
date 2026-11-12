# Changelog

## 1.1.0 — 2026-11-11

- Menu bar app with its own anchored-mic icon (crossed out when paused), no Dock icon. App icon uses the same glyph.
- Menu with pause/resume, preferred input/output pickers, *Keep fixed* toggles, switch counter, settings & history window, open at login.
- Opening the app again (Finder/Spotlight) brings the settings window of the running instance.

## 1.0.0 — 2026-11-11

- First release.
- Undo automatic input/output switches when a new audio device connects (8 s window).
- Manual choices become the new preferred device; disconnected preferred devices are restored on return.
- Independent *Keep fixed* for input (on by default) and output (off by default); sound effects follow the output rule.
- Dock app, single instance, open at login, in-app history and log file.
- English, Português (Brasil), Español, Français, Deutsch.
- Universal binary (arm64 + x86_64), macOS 14+.
- `simulate_plug` end-to-end checker.
