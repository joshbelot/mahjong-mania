# Agent instructions

This is a **native iOS app** (Swift 6 + SwiftUI, iOS 17+). There is no Expo, React Native or JavaScript.

- The full plan is in `docs/SPEC.md`. Read §0 first, then work **one phase per PR**, in order: §13 for v1.0 and §17.9 for v1.1 (both done), §18.12 for v1.2.
- The Xcode project is **generated** by XcodeGen from `project.yml`. Never hand-edit or commit `*.xcodeproj`. Change `project.yml`, then run `xcodegen generate`.
- All game logic lives in the local Swift package `Packages/MahjongCore`. It is Foundation-only (no SwiftUI/UIKit) and must stay that way so `swift test` runs anywhere, including Linux.
- Before pushing, run `swift test --package-path Packages/MahjongCore`. On macOS, also run `tools/test.sh`.
- v1.0 and v1.1 are done and on TestFlight. The current work is **version 1.2: `docs/SPEC.md` §18** (Practice becomes a game), phases 21–27 in order, one PR per phase, ticking the §18.12 boxes and the table in `docs/PROGRESS.md` in the same PR. When all of them are merged, ship 1.2 to TestFlight as §18.11 says.
- Releases go to TestFlight via `tools/upload_testflight.sh` (see `RELEASING.md`). Never print, log or commit signing credentials (`ASC_*`, `DEVELOPMENT_TEAM`, `.p8` files).

## Working on the owner's Mac (stabilisation)

The app was written entirely in a Linux sandbox with no Swift toolchain; until 2026-10-13 it had only ever been compiled and run by CI, and nobody had looked at it running. This Mac has Xcode 27, Swift 6.4, XcodeGen and iPhone 17-family simulators, so verify locally instead of waiting for CI.

- **Look at the app, don't just run tests.** For any UI change or QA item, build, launch it in the simulator, drive the flow and take screenshots. A green test run is not evidence that a screen looks right.
- `tools/test.sh` runs everything (core tests, `xcodegen generate`, app unit + UI tests); the UI suite takes 25–50 minutes, so while iterating run a single class with `xcodebuild test … -only-testing:AppUITests/<Class>` and run the whole script once before pushing.
- **There is no CI.** The owner disabled the GitHub Actions workflow on 2026-10-13 and wants it kept off: do not re-enable it, trigger it, wait for it, or add new workflows. Local runs on this Mac are the only gate, so say in each PR exactly what you ran and what passed.
- Zero compiler warnings is part of the definition of done (SPEC §14.3). Check the build log.
- Every bug fix gets a test that fails without it: in `MahjongCore` if it is logic, otherwise `AppTests`, and a UI test only when nothing lower can catch it.
- Branches are `claude/<short-topic>`, one PR per phase or backlog item, merged only after `tools/test.sh` passes locally on the branch (for a docs-only change, nothing needs to run). Do not push to `main` directly except for docs-only updates to `docs/PROGRESS.md` and `docs/DECISIONS.md`.
- Record any deviation from the spec, and any bug whose fix changed behaviour, in `docs/DECISIONS.md`.
- **Releases:** the signing variables live in the owner's `~/.zshrc`, so run the script as `zsh -ic 'tools/upload_testflight.sh …'`. An agent may always run `--dry-run`. An agent runs the real upload (no `--dry-run`) **only** when the owner's instructions for the current round say so, as SPEC §17.8 did for 1.1 and §18.11 does for 1.2, and only from a clean `main` after every phase of the round is merged. Never echo the environment or `cat` `~/.zshrc`.
- App Store Connect validates things a dry run can't (2026-10-13: iPad multitasking orientations). Before the real upload, validate the exported `.ipa` with `xcrun altool --validate-app -f <ipa> -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"` inside the same `zsh -ic` shell, and fix anything it reports first.
- Things that need a physical iPhone (haptics, real-device speed, VoiceOver by hand, installing the TestFlight build) are owner steps. Leave those boxes unticked and list them for the owner rather than marking them done.
