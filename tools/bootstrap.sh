#!/bin/zsh
# Checks the toolchain and generates the Xcode project from project.yml.
set -euo pipefail
cd "${0:A:h}/.."

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode command-line tools not found. Install Xcode 26+ and run: xcode-select --install" >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew..."
    brew install xcodegen
  else
    echo "XcodeGen is required: https://github.com/yonaskolb/XcodeGen (brew install xcodegen)" >&2
    exit 1
  fi
fi
xcodegen generate
echo "Done. Open MahjongMania.xcodeproj."
