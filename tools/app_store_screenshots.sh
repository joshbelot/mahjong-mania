#!/bin/zsh
# Makes the App Store screenshots (SPEC §19.7): AppStore/screenshots/6.9/*.png at 1320 x 2868 on the
# iPhone 17 Pro Max simulator, light mode, 9:41, full battery. Also writes a 1284 x 2778 set (6.5 inch)
# by scaling. Run from the repository root. Needs Xcode, XcodeGen and `sips`.
set -euo pipefail
cd "${0:A:h}/.."
UDID=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
OUT="$PWD/AppStore/screenshots/6.9"
rm -rf "$OUT"; mkdir -p "$OUT"
xcodegen generate >/dev/null
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --operatorName ""
trap 'xcrun simctl status_bar "$UDID" clear' EXIT
TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test -project MahjongMania.xcodeproj -scheme MahjongMania \
  -destination "id=$UDID" -only-testing:MahjongManiaUITests/AppStoreScreenshotTests CODE_SIGNING_ALLOWED=NO
OUT65="$PWD/AppStore/screenshots/6.5"
rm -rf "$OUT65"; mkdir -p "$OUT65"
for f in "$OUT"/*.png; do
  sips -z 2778 1284 "$f" --out "$OUT65/$(basename "$f")" >/dev/null
done
sips -g pixelWidth -g pixelHeight "$OUT"/*.png "$OUT65"/*.png | grep -E "png|pixel"
