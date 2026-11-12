#!/bin/zsh
# Builds FixMacAudioInput.app without an Xcode project.
#
#   ./build.sh              build app + test tool into ./build
#   ./build.sh --install    ...and copy the app to /Applications
#   ./build.sh --package    ...and create dist/*.zip, dist/*.dmg and SHA-256 sums
#
# SIGN_IDENTITY="Developer ID Application: ..." ./build.sh   signs with a real identity
# (default: ad-hoc "-").
set -euo pipefail
cd "${0:A:h}"

NAME=FixMacAudioInput
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
BUILD=build
APP="$BUILD/$NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS=(arm64 x86_64)

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ icon"
swiftc -swift-version 5 Sources/StatusIcon.swift Tools/generate_icon/main.swift -o "$BUILD/generate_icon"
"$BUILD/generate_icon" "$BUILD/AppIcon.iconset"
cp "$BUILD/AppIcon.iconset/icon_128x128@2x.png" docs/icon.png
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ app $VERSION (universal: ${ARCHS[*]})"
SLICES=()
for arch in $ARCHS; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos14.0" \
    -framework CoreAudio -framework AppKit -framework SwiftUI -framework ServiceManagement \
    Sources/*.swift -o "$BUILD/$NAME-$arch"
  SLICES+=("$BUILD/$NAME-$arch")
done
lipo -create $SLICES -output "$APP/Contents/MacOS/$NAME"
rm -f $SLICES
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
for f in "$APP"/Contents/Resources/*.lproj/Localizable.strings; do plutil -lint "$f" >/dev/null; done
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "→ test tool (simulate_plug)"
swiftc -O -swift-version 5 -framework CoreAudio \
  Sources/CoreAudioHelpers.swift Sources/L10n.swift Tests/main.swift -o "$BUILD/simulate_plug"

if [[ " $* " == *" --install "* ]]; then
  echo "→ installing to /Applications"
  osascript -e "tell application id \"br.com.pedroberaldo.$NAME\" to quit" 2>/dev/null || true
  sleep 1
  rm -rf "/Applications/$NAME.app"
  ditto "$APP" "/Applications/$NAME.app"
fi

if [[ " $* " == *" --package "* ]]; then
  echo "→ packaging"
  mkdir -p dist
  ZIP="dist/$NAME-$VERSION.zip"
  DMG="dist/$NAME-$VERSION.dmg"
  rm -f "$ZIP" "$DMG"
  ditto -c -k --keepParent "$APP" "$ZIP"
  STAGE="$BUILD/dmg"
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/$NAME.app"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -quiet -volname "$NAME $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
  rm -rf "$STAGE"
  (cd dist && shasum -a 256 "$NAME-$VERSION.zip" "$NAME-$VERSION.dmg" > "$NAME-$VERSION.sha256")
  ls -la dist
fi
echo "ok: $PWD/$APP"
