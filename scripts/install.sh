#!/bin/sh
# Installs the latest Claude Meter release into /Applications.
#   curl -fsSL https://raw.githubusercontent.com/bsc2fast/claude-meter-macos/main/scripts/install.sh | sh
# Downloading with curl doesn't add the quarantine flag, so macOS won't block this
# ad-hoc signed build; we also clear it in case the zip came from a browser.
set -eu
REPO="bsc2fast/claude-meter-macos"
URL="https://github.com/$REPO/releases/latest/download/ClaudeMeter.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Claude Meter…"
curl -fsSL "$URL" -o "$TMP/ClaudeMeter.zip"
ditto -x -k "$TMP/ClaudeMeter.zip" "$TMP"

pkill -x ClaudeMeter 2>/dev/null || true
rm -rf /Applications/ClaudeMeter.app
mv "$TMP/ClaudeMeter.app" /Applications/
xattr -dr com.apple.quarantine /Applications/ClaudeMeter.app 2>/dev/null || true
open /Applications/ClaudeMeter.app
echo "Installed. Look for the meter in your menu bar (⌘-drag to move it)."
