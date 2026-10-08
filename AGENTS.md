# Agent instructions

This is a **native iOS app** (Swift 6 + SwiftUI, iOS 17+). There is no Expo, React Native or JavaScript.

- The full plan is in `docs/SPEC.md`. Read §0 first, then work **one phase from §13 per PR**, in order.
- The Xcode project is **generated** by XcodeGen from `project.yml`. Never hand-edit or commit `*.xcodeproj`. Change `project.yml`, then run `xcodegen generate`.
- All game logic lives in the local Swift package `Packages/MahjongCore`. It is Foundation-only (no SwiftUI/UIKit) and must stay that way so `swift test` runs anywhere, including Linux.
- Before pushing, run `swift test --package-path Packages/MahjongCore`. On macOS, also run `tools/test.sh`.
- Releases go to TestFlight via `tools/upload_testflight.sh` (see `RELEASING.md`). Never print, log or commit signing credentials (`ASC_*`, `DEVELOPMENT_TEAM`, `.p8` files).
