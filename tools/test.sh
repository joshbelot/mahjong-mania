#!/bin/zsh
# Runs the package tests, regenerates the project, and runs the app unit + UI tests on a simulator.
# Set RESULT_BUNDLE to choose where the .xcresult goes (default build/Tests.xcresult).
set -euo pipefail
cd "${0:A:h}/.."

swift test --package-path Packages/MahjongCore

command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found (brew install xcodegen)" >&2; exit 1; }
xcodegen generate

DEST_ID=$(tools/simulator_id.sh)
RESULT_BUNDLE=${RESULT_BUNDLE:-build/Tests.xcresult}
mkdir -p "$(dirname "$RESULT_BUNDLE")"
rm -rf "$RESULT_BUNDLE"

xcodebuild test \
  -project MahjongMania.xcodeproj \
  -scheme MahjongMania \
  -destination "id=$DEST_ID" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO
