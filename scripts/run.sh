#!/usr/bin/env bash
#
# Build from the command line and launch the app.
#
# This signs with your Apple Development certificate so macOS remembers the
# Microphone, Accessibility, and Input Monitoring permissions across rebuilds.
# You grant them once, then never again.
#
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED=".build/dd"
APP="$DERIVED/Build/Products/Debug/VoiceWritter.app"

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Building"
xcodebuild \
  -project VoiceWritter.xcodeproj \
  -scheme VoiceWritter \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -skipMacroValidation \
  build

# Re-sign with your Apple Development certificate so macOS keeps the
# Microphone, Accessibility, and Input Monitoring permissions across rebuilds.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' 'NR==1{print $2}')"
if [ -n "$IDENTITY" ]; then
  echo "==> Re-signing with: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" \
    --entitlements Config/VoiceWritter.entitlements "$APP"
  codesign -dvv "$APP" 2>&1 | grep -E "Authority|Identifier" | head -3
else
  echo "==> No developer certificate found; leaving ad hoc signature."
fi

echo "==> Launching $APP"
open "$APP"
