# Progress

Source of truth for where the build is. Updated by the lead on `main`.

| Phase | Status | Notes |
|---|---|---|
| 0 Foundation | merged | PR 3 |
| 1 Tiles | merged | PR 4 |
| 2 Notation | merged | PR 5 |
| 3 Engine | merged | PR 6 |
| 4 Suggestions & scout | merged | PR 7 |
| 5 Scoring | merged | PR 8 |
| 6 Design system | merged | PR 11 |
| 7 Stores | merged | PR 9 |
| 8 Cards | merged | PR 14 |
| 9 Game Night | merged | PR 16 |
| 10 Helper | merged | PR 18 |
| 11 Learn | merged (11a content PR 10, 11b screens PR 13) | |
| 12 Settings, polish, release | merged (12a PR 12, 12b PR 15, 12c PR 17); owner steps and QA remain, see backlog below | |

## Stabilisation backlog (current work)

All phases are merged and CI on `main` is green (run of 2026-10-09 on `57d6397`). The app has still never been run by a person. Work these in order, one PR each; tick the box in the same PR.

Baseline on the owner's Mac, 2026-10-13 (Xcode 27.0, Swift 6.4): `swift test` passes (171 tests); `xcodebuild build-for-testing` succeeds with 2 warnings; the app unit and UI tests have **not** been run locally yet.

- [x] **1. Full local test run.** `tools/test.sh` on Xcode 27. Fix anything that fails locally without breaking CI.
- [ ] **2. Zero warnings.** `App/Features/Helper/HelperView.swift:195` (unused `withAnimation` result) and `AppTests/StoresTests.swift:219,222` (redundant `#require` on a non-optional).
- [ ] **3. Simulator QA pass.** Walk every item of the manual QA checklist (SPEC §13) in the simulator, in light and dark mode and at the largest accessibility text size, with screenshots. Fix each bug found (with a test) or, if it is a product question, list it under "Open questions" below. Tick the simulator half of the SPEC checklist when it passes.
- [ ] **4. Core coverage.** `swift test --enable-code-coverage --package-path Packages/MahjongCore`, report line coverage with `llvm-cov`, add tests until it is ≥ 95% (SPEC §14.1). It was printed by CI but never checked.
- [ ] **5. Helper responsiveness.** Analysis runs on the main actor. Measure a tile tap with a full rack on the simulator; if it is not comfortably under a frame budget the user would notice (aim < 50 ms), move analysis off the main actor without changing results.
- [ ] **6. Release dry run.** `zsh -ic 'tools/upload_testflight.sh --dry-run'`. Fix script problems until it ends with "Dry run complete" and the build number is unchanged; tick the SPEC Phase 12 dry-run box. Never run it without `--dry-run`.
- [ ] **7. Cards editor data loss.** Editing a hand in a user card rewrites the card text and drops comments and invalid lines (DECISIONS, Phase 8). Preserve them.

Item 1 result (2026-10-13): `tools/test.sh` on Xcode 27 passes (core 171 tests; app unit and UI suites green, 29 min). One flake: `GameNightTests.testScriptedGameNightLight` failed on iteration 1 ("after editing hand 1": only Dee's score was visible, the other rows were not found) and passed on the retry. `expectScores` only scrolled when the first expected row was missing; it now scrolls whenever any row is missing.

**Owner only:** physical-iPhone QA and the real upload, per `docs/RELEASE_HANDOFF.md`.

### Open questions for the owner

_None yet._

**Environment notes:** phases 0–12 were written in a sandbox with no Swift toolchain (see DECISIONS.md); the owner's Mac has one, see `AGENTS.md`. The `core` job runs on every push; the `ios` job runs on PRs and `main` (~10 min; a simulator launch timeout flake can happen, the test step retries failing tests and a failed job can be re-run once). UI screenshots are published by CI to the `ci-screenshots` branch (`pr-<number>/`); view them via `raw.githubusercontent.com`.
