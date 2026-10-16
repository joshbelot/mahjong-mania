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

## Version 1.1 (current work)

Plan: `docs/SPEC.md` §17. v1.0 build 2 is on TestFlight (2026-10-13). One PR per phase, in order.

| Phase | Status | PR |
|---|---|---|
| 13 Plain words (Show/Hide tiles, exposed sets explained) | merged | [#27](https://github.com/joshbelot/mahjong-mania/pull/27) |
| 14 Charleston seat, pass tracker, locked suggestion | PR | |
| 15 Rule book core (MahjongCore) | not started | |
| 16 House rules screens and Learn | not started | |
| 17 Blanks | not started | |
| 18 Tile styles | not started | |
| 19 QR card sharing | not started | |
| 20 1.1 QA and TestFlight upload | not started | |

### Open questions for the owner (1.1)

_None yet._

## Stabilisation backlog (v1.0, done)

All phases are merged. A person has not yet used the app on a device. Work these in order, one PR each; tick the box in the same PR.

Baseline on the owner's Mac, 2026-10-13 (Xcode 27.0, Swift 6.4): `swift test` passed (171 tests); the first full `tools/test.sh` run passed.

- [x] **1. Full local test run.** `tools/test.sh` on Xcode 27. Fix anything that fails locally without breaking CI.
- [x] **2. Zero warnings.** `App/Features/Helper/HelperView.swift:195` (unused `withAnimation` result) and `AppTests/StoresTests.swift:219,222` (redundant `#require` on a non-optional).
- [x] **3. Simulator QA pass.** Walk every item of the manual QA checklist (SPEC §13) in the simulator, in light and dark mode and at the largest accessibility text size, with screenshots. Fix each bug found (with a test) or, if it is a product question, list it under "Open questions" below. Tick the simulator half of the SPEC checklist when it passes.
- [x] **4. Core coverage.** `swift test --enable-code-coverage --package-path Packages/MahjongCore`, report line coverage with `llvm-cov`, add tests until it is ≥ 95% (SPEC §14.1). It was printed by CI but never checked.
- [x] **5. Helper responsiveness.** Analysis runs on the main actor. Measure a tile tap with a full rack on the simulator; if it is not comfortably under a frame budget the user would notice (aim < 50 ms), move analysis off the main actor without changing results.
- [x] **6. Release dry run.** `zsh -ic 'tools/upload_testflight.sh --dry-run'`. Fix script problems until it ends with "Dry run complete" and the build number is unchanged; tick the SPEC Phase 12 dry-run box. Never run it without `--dry-run`.
- [x] **7. Cards editor data loss.** Editing a hand in a user card rewrites the card text and drops comments and invalid lines (DECISIONS, Phase 8). Preserve them.

Item 4 result (2026-10-13): core line coverage is already 97.58% (2054 of 2105 lines, `llvm-cov` via `swift test --enable-code-coverage`), above the 95% target, so no tests were added. The lowest files are `ScoringTypes.swift` 91.6%, `NotationTypes.swift` 92.9% and `Suggest.swift` 93.3%.

Item 1 result (2026-10-13): `tools/test.sh` on Xcode 27 passes (core 171 tests; app unit and UI suites green, 29 min). One flake: `GameNightTests.testScriptedGameNightLight` failed on iteration 1 ("after editing hand 1": only Dee's score was visible, the other rows were not found) and passed on the retry. `expectScores` only scrolled when the first expected row was missing; it now scrolls whenever any row is missing.

Item 3 result (2026-10-13): walked the SPEC §13 QA checklist on an iPhone 17 Pro simulator (iOS 26.5) in light, dark and the largest accessibility text size (AX5), with screenshots from manual driving and from the UI suite. Passed in the simulator: onboarding to the Game tab; four-player game with discard, self-pick, jokerless, wall game, adjustment, edit, undo, end, settle-up and share text; Helper Charleston (jokers never passed, also fuzzed over 400 random racks), Playing discards and call check, Scout; Cards duplicate, edit, import (with a bad line reported), share sheet, and an imported card used as the active card by the Helper; Learn topics and both drills; dark mode; relaunch with the session intact; no network code at all (nothing to break in airplane mode). Bugs found and fixed (PR 21, test `LargeTextTests`): at AX5 the scoreboard truncated a name to "..." and wrapped "+120" to "+12 / 0", buttons broke mid-word ("Reco-rd a ha..."), pills wrapped letter by letter, and the Helper chips, rack header, result cards, summary, players and seat rows were squeezed. They now stack at accessibility sizes. Seen once and not reproduced: after onboarding with Coach selected the first tap on "Start game night" landed on the Helper tab. **Not verifiable here:** VoiceOver by hand, haptics, keep-awake on a real screen, and the physical iPhone half of the checklist; those boxes stay unticked.

Item 5 result (2026-10-13): no change needed. A full-rack tap costs at most 4.4 ms in Release (closest hands 0.3 ms, discard advice 3.5 ms) and 66 ms in Debug; see DECISIONS.

Item 7 result (2026-10-13): fixed in PR 23; see DECISIONS.

Item 6 result (2026-10-13): `zsh -ic 'tools/upload_testflight.sh --dry-run'` on `main` at `e0524a0` ran preflight, tests, archive and export and ended with "Dry run complete: archive and export succeeded. Nothing was uploaded and the build number is unchanged (1)." No script changes were needed. The real upload is still the owner's step.

**Owner only:** physical-iPhone QA and the real upload, per `docs/RELEASE_HANDOFF.md`.

### Open questions for the owner

Answered by the owner ("choose by best practice and consistency") and done in the follow-up PR: unique player names (typing an existing name picks that person), Share card as `<name>.txt`, keep-awake takes effect immediately, Import keeps skipping invalid lines (the user is told first).

Line identity across card edits was fixed too (line IDs are `L_<hash>`, see DECISIONS). Remaining limitation: editing a hand's own text gives it a new ID, so its win count starts again.

**Environment notes:** phases 0–12 were written in a sandbox with no Swift toolchain and verified only by CI (see DECISIONS.md). CI has been disabled by the owner since 2026-10-13; everything is now verified locally on the owner's Mac, see `AGENTS.md`. The last green CI run on `main` was on `57d6397` (2026-10-09); screenshots from that period are on the `ci-screenshots` branch.
