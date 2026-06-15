#!/usr/bin/env bash
#
# Install Voice Writter permanently:
#   - build the app
#   - sign it with your Apple Development certificate (so permissions persist)
#   - copy it into /Applications
#   - set it to launch at login
#
# Usage:
#   ./scripts/install.sh            # optimized Release build (recommended)
#   ./scripts/install.sh Debug      # faster build, slower grammar model
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-Release}"
DERIVED=".build/dd"
SRC="$DERIVED/Build/Products/$CONFIG/VoiceWritter.app"
# Install into the user's Applications folder. macOS protects /Applications
# (App Management), which blocks scripted installs, especially on managed Macs.
APPS_DIR="$HOME/Applications"
DEST="$APPS_DIR/VoiceWritter.app"
mkdir -p "$APPS_DIR"

IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' 'NR==1{print $2}')"
if [ -z "$IDENTITY" ]; then
  echo "No code-signing certificate found. Permissions will not persist across rebuilds." >&2
fi

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Building ($CONFIG). This can take several minutes."
xcodebuild \
  -project VoiceWritter.xcodeproj \
  -scheme VoiceWritter \
  -configuration "$CONFIG" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -skipMacroValidation \
  build

echo "==> Installing into $DEST"
pkill -x VoiceWritter 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

if [ -n "$IDENTITY" ]; then
  echo "==> Signing the installed app with: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" \
    --entitlements Config/VoiceWritter.entitlements "$DEST"
fi

echo "==> Setting it to launch at login"
PLIST="$HOME/Library/LaunchAgents/com.sadmansoumik.voicewritter.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sadmansoumik.voicewritter</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>$DEST</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "==> Launching the installed app"
open "$DEST"

echo
echo "Done. Voice Writter is installed in $DEST and will start automatically at login."
