#!/bin/zsh
# Regenerates docs/screenshots/*.png (demo data, no real devices). Run after ./build.sh.
set -euo pipefail
cd "${0:A:h}/../.."
SHOT=build/Screenshot.app
rm -rf "$SHOT"
ditto build/FixMacAudioInput.app "$SHOT"
swiftc -O -swift-version 5 -D SCREENSHOT \
  -framework CoreAudio -framework AppKit -framework SwiftUI -framework ServiceManagement \
  Sources/AudioGuard.swift Sources/ContentView.swift Sources/CoreAudioHelpers.swift \
  Sources/L10n.swift Sources/StatusIcon.swift Tools/screenshot/main.swift \
  -o "$SHOT/Contents/MacOS/screenshot"
rm -rf docs/screenshots; mkdir -p docs/screenshots
# Light only: dark appearance does not render reliably off-screen.
for lang in en pt-BR; do
  "$SHOT/Contents/MacOS/screenshot" "docs/screenshots/window-$lang.png" light -AppleLanguages "($lang)"
done
rm -rf "$SHOT"
