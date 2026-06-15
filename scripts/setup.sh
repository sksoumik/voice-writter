#!/usr/bin/env bash
#
# One time setup: install tools, generate the Xcode project, and open it.
#
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Checking XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen with Homebrew..."
  brew install xcodegen
fi

echo "==> Checking the Metal Toolchain (needed to build MLX shaders)"
if ! xcrun --find metal >/dev/null 2>&1; then
  echo "Downloading the Metal Toolchain (one time, a few hundred MB)..."
  xcodebuild -downloadComponent MetalToolchain
fi

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Opening Xcode"
open VoiceWritter.xcodeproj

cat <<'NOTE'

Next steps in Xcode:
  1. Select the "VoiceWritter" scheme.
  2. Press Run (Cmd+R).
  3. When prompted, click "Trust & Enable" for the mlx-swift-lm macro.

The first build downloads and compiles Swift packages, so it takes a few minutes.
On first launch, grant Microphone and Accessibility permissions in the setup window.
NOTE
