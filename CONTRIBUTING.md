# Contributing

Thanks for helping. FixMacAudioInput is intentionally small: one job, no dependencies.

## Reporting a bug

Open an [issue](https://github.com/pedroberaldo87/FixMacAudioInput/issues/new/choose) with:

- macOS version and Mac model (Apple silicon / Intel);
- the devices involved (e.g. "AirPods Pro 2, Shure MV7 over USB");
- what you expected and what happened;
- the relevant lines of `~/Library/Logs/FixMacAudioInput.log`.

## Development

```sh
./build.sh                                   # build/FixMacAudioInput.app
open build/FixMacAudioInput.app --args -protectOutput YES
build/simulate_plug input auto               # must PASS
build/simulate_plug input manual             # must PASS
build/simulate_plug output auto              # must PASS
build/simulate_plug output manual            # must PASS
```

Run all four `simulate_plug` checks before opening a pull request that touches `AudioGuard.swift`.
Quit any other running copy first (the app is single-instance).

## Translations

1. Copy `Resources/Localization/en.lproj` to `<code>.lproj` (e.g. `it.lproj`).
2. Translate the values; keep the placeholders (`%@`, `%1$@`, `%ld`, `%2$ld`) as they are.
3. Add the code to `CFBundleLocalizations` in `Resources/Info.plist`.
4. Run `./build.sh` — it lints every `.strings` file.

## Screenshots and icon

- `Tools/screenshot/run.sh` regenerates `docs/screenshots/` with demo devices (run after `./build.sh`).
- The icon is drawn in code (`Sources/StatusIcon.swift`); `build.sh` renders the app icon from it.
  `docs/glyph.svg` mirrors the same geometry for the website.

## Releasing (maintainers)

1. Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Resources/Info.plist` and update `CHANGELOG.md`.
2. `./build.sh --package`
3. Tag `vX.Y.Z`, push, and attach `dist/*.dmg`, `dist/*.zip` and `dist/*.sha256` to a GitHub release.
