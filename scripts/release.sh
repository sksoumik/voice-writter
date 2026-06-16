#!/usr/bin/env bash
#
# Build, package a .dmg, and publish a GitHub Release.
#
# Usage:
#   ./scripts/release.sh v0.1.0
#
# Signing:
#   - If you have a "Developer ID Application" certificate, the app is signed
#     with it. If you also set the notary credentials below, it is notarized and
#     stapled, which gives downloaders a clean, warning free install.
#   - Otherwise the app is ad hoc signed. It still runs, but downloaders must
#     remove the quarantine flag once (the release notes explain how).
#
# Optional notarization environment variables (only used with a Developer ID):
#   AC_API_KEY_ID, AC_API_ISSUER_ID, AC_API_KEY_PATH  (App Store Connect API key)
#
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: ./scripts/release.sh vX.Y.Z}"
DERIVED=".build/dd"
APP="$DERIVED/Build/Products/Release/VoiceWritter.app"
DIST="dist"
DMG="$DIST/VoiceWritter-$VERSION.dmg"

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Building (Release)"
xcodebuild \
  -project VoiceWritter.xcodeproj \
  -scheme VoiceWritter \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  build

echo "==> Signing"
DEVID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')"
if [ -n "${DEVID:-}" ]; then
  echo "Using Developer ID: $DEVID"
  codesign --force --deep --options runtime --timestamp \
    --entitlements Config/VoiceWritter.entitlements --sign "$DEVID" "$APP"
else
  echo "No Developer ID certificate found; ad hoc signing."
  codesign --force --deep --sign - \
    --entitlements Config/VoiceWritter.entitlements "$APP"
fi

echo "==> Packaging the disk image"
mkdir -p "$DIST"
rm -f "$DMG"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Voice Writter" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# Notarize only when we used a Developer ID and have notary credentials.
if [ -n "${DEVID:-}" ] && [ -n "${AC_API_KEY_ID:-}" ] && [ -n "${AC_API_ISSUER_ID:-}" ] && [ -n "${AC_API_KEY_PATH:-}" ]; then
  echo "==> Notarizing"
  xcrun notarytool submit "$DMG" --key "$AC_API_KEY_PATH" --key-id "$AC_API_KEY_ID" --issuer "$AC_API_ISSUER_ID" --wait
  xcrun stapler staple "$DMG"
  NOTARIZED=1
else
  NOTARIZED=0
fi

echo "==> Publishing the GitHub release"
if [ "$NOTARIZED" = "1" ]; then
  NOTES="Voice Writter $VERSION

On device voice to text with local grammar correction for macOS (Apple Silicon).

Install: open the .dmg, drag Voice Writter to Applications, launch it, and grant Microphone, Accessibility, and Input Monitoring when asked. Requires an Apple Silicon Mac and macOS 14 or later. About 2 to 3 GB of models download on first run."
else
  NOTES="Voice Writter $VERSION

On device voice to text with local grammar correction for macOS (Apple Silicon).

This build is not notarized, so macOS will not open it directly. Install it like this:
1. Open the .dmg and drag Voice Writter to your Applications folder.
2. Remove the quarantine flag once, in Terminal:
   xattr -dr com.apple.quarantine /Applications/VoiceWritter.app
3. Open Voice Writter and grant Microphone, Accessibility, and Input Monitoring when asked.

Requires an Apple Silicon Mac (M1 or newer) and macOS 14 or later. About 2 to 3 GB of models download on first run."
fi

if gh release view "$VERSION" >/dev/null 2>&1; then
  gh release upload "$VERSION" "$DMG" --clobber
else
  gh release create "$VERSION" "$DMG" --title "Voice Writter $VERSION" --notes "$NOTES"
fi

echo "==> Done: $DMG published as release $VERSION"
