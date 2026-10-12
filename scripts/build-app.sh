#!/bin/sh
# Builds build/ClaudeMeter.app (menu-bar only, ad-hoc signed).
# Usage: scripts/build-app.sh [--install | --zip]   (--install copies to /Applications, --zip packs dist/ClaudeMeter.zip)
set -eu
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release/ClaudeMeter"

APP="build/ClaudeMeter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClaudeMeter"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Claude Meter</string>
  <key>CFBundleDisplayName</key><string>Claude Meter</string>
  <key>CFBundleIdentifier</key><string>org.sclab.claude-meter</string>
  <key>CFBundleExecutable</key><string>ClaudeMeter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x ClaudeMeter 2>/dev/null || true
  rm -rf /Applications/ClaudeMeter.app
  cp -R "$APP" /Applications/
  open /Applications/ClaudeMeter.app
  echo "Installed to /Applications and launched"
fi

if [ "${1:-}" = "--zip" ]; then
  mkdir -p dist
  rm -f dist/ClaudeMeter.zip
  ditto -c -k --keepParent "$APP" dist/ClaudeMeter.zip
  echo "Packed dist/ClaudeMeter.zip"
fi
