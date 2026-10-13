# Agent instructions

This is a **native iOS app** (Swift 6 + SwiftUI, iOS 17+). There is no Expo, React Native or JavaScript.

- The full plan is in `docs/SPEC.md`. Read §0 first, then work **one phase from §13 per PR**, in order.
- The Xcode project is **generated** by XcodeGen from `project.yml`. Never hand-edit or commit `*.xcodeproj`. Change `project.yml`, then run `xcodegen generate`.
- All game logic lives in the local Swift package `Packages/MahjongCore`. It is Foundation-only (no SwiftUI/UIKit) and must stay that way so `swift test` runs anywhere, including Linux.
- Before pushing, run `swift test --package-path Packages/MahjongCore`. On macOS, also run `tools/test.sh`.
- All §13 phases (0–12) are merged. The work now is the **stabilisation backlog in `docs/PROGRESS.md`**: take the top unticked item, one small PR per item, tick it in the same PR.
- Releases go to TestFlight via `tools/upload_testflight.sh` (see `RELEASING.md`). Never print, log or commit signing credentials (`ASC_*`, `DEVELOPMENT_TEAM`, `.p8` files).

## Working on the owner's Mac (stabilisation)

The app was written entirely in a Linux sandbox with no Swift toolchain; until 2026-10-13 it had only ever been compiled and run by CI, and nobody had looked at it running. This Mac has Xcode 27, Swift 6.4, XcodeGen and iPhone 17-family simulators, so verify locally instead of waiting for CI.

- **Look at the app, don't just run tests.** For any UI change or QA item, build, launch it in the simulator, drive the flow and take screenshots. A green test run is not evidence that a screen looks right.
- `tools/test.sh` runs everything (core tests, `xcodegen generate`, app unit + UI tests); the UI suite takes 25–50 minutes, so while iterating run a single class with `xcodebuild test … -only-testing:AppUITests/<Class>` and run the whole script once before pushing.
- CI uses `latest-stable` Xcode, which may be older than the local Xcode 27. A fix for a local-only failure must not break CI; both have to be green.
- Zero compiler warnings is part of the definition of done (SPEC §14.3). Check the build log.
- Every bug fix gets a test that fails without it: in `MahjongCore` if it is logic, otherwise `AppTests`, and a UI test only when nothing lower can catch it.
- Branches are `claude/<short-topic>`, one PR per backlog item, merged only when both CI jobs are green. Do not push to `main` directly except for docs-only updates to `docs/PROGRESS.md` and `docs/DECISIONS.md`.
- Record any deviation from the spec, and any bug whose fix changed behaviour, in `docs/DECISIONS.md`.
- **Releases:** the signing variables live in the owner's `~/.zshrc`, so the script must be run as `zsh -ic 'tools/upload_testflight.sh --dry-run'`. An agent may run `--dry-run`. An agent must **never** run the script without `--dry-run`; the real upload is the owner's step. Never echo the environment or `cat` `~/.zshrc`.
- Things that need a physical iPhone (haptics, real-device speed, VoiceOver by hand, installing the TestFlight build) are owner steps. Leave those boxes unticked and list them for the owner rather than marking them done.
