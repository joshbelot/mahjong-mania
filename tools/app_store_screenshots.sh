#!/bin/zsh
# Makes the App Store screenshots (SPEC §19.7): AppStore/screenshots/6.9/*.png at 1320 x 2868 on the
# iPhone 17 Pro Max simulator, light mode, 9:41, full battery.
# Run from the repository root. Needs Xcode and XcodeGen.
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
python3 - "$OUT" <<'PYCODE'
import pathlib, struct, sys
root = pathlib.Path(sys.argv[1])
expected = {f"{i:02d}-{name}.png" for i, name in enumerate(
    ["practice-path", "lesson-feedback", "three-stars", "helper", "scoreboard", "settle-up", "cards", "house-rules"], 1)}
actual = {p.name for p in root.glob("*.png")}
if actual != expected:
    sys.exit(f"Screenshot set mismatch: missing {sorted(expected - actual)}, unexpected {sorted(actual - expected)}")
for path in sorted(root.glob("*.png")):
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 24 or struct.unpack(">II", data[16:24]) != (1320, 2868):
        sys.exit(f"Invalid screenshot dimensions or PNG: {path.name}")
    print(f"{path.name}: 1320 x 2868")
PYCODE
