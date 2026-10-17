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
| 14 Charleston seat, pass tracker, locked suggestion | merged | [#28](https://github.com/joshbelot/mahjong-mania/pull/28) |
| 15 Rule book core (MahjongCore) | merged | [#29](https://github.com/joshbelot/mahjong-mania/pull/29) |
| 16 House rules screens and Learn | merged | [#30](https://github.com/joshbelot/mahjong-mania/pull/30) |
| 17 Blanks | merged | [#31](https://github.com/joshbelot/mahjong-mania/pull/31) |
| 18 Tile styles | merged | [#32](https://github.com/joshbelot/mahjong-mania/pull/32) |
| 19 QR card sharing | merged | [#33](https://github.com/joshbelot/mahjong-mania/pull/33) |
| 20 1.1 QA and TestFlight upload | PR | [#34](https://github.com/joshbelot/mahjong-mania/pull/34) |

### 1.1 QA pass (2026-10-16, iPhone 17 Pro and iPhone Air simulators, iOS 26.5)

- **Every phase** was built, driven and looked at in the simulator in light, dark and the largest accessibility text size before it merged (screens are listed in each PR). `tools/test.sh` passed on every phase branch (core 208 tests, app unit 270, app UI 60 by Phase 19; the UI suite takes about 35 minutes).
- **SPEC §13 checklist, simulator half:** covered by the UI suite on the final code: onboarding to the Game tab and a scripted game night with discard, self-pick, jokerless, wall game, adjustment, edit, undo, relaunch and settle-up (GameNightTests); Helper Charleston (jokers never passed), Playing and call check, Scout (HelperTests); Cards duplicate, edit, import and share (CardsTests); every Learn topic and both drills (LearnOnboardingTests); Settings and reset (SettingsTests); large text (LargeTextTests); dark mode in all of them. No network code exists, so airplane mode cannot change anything.
- **1.1 features:** the new tests listed under each phase's PR, plus a look at each new screen. The QA pass found one wording bug (the rule text said "pay the hand's value the hand's points" for a single choice); fixed in the release PR with a test over every choice of every rule.
- **Not verifiable here, owner steps (boxes left open):** VoiceOver by hand on the new screens, haptics, scanning a card's QR code with the real iPhone Camera and seeing iOS offer to open the app, real-device speed, and installing the TestFlight build.

### Open questions for the owner (1.1)

Each of these was a product judgement the spec did not settle. The choice made is the one most consistent with the rest of the app; the owner can change any of them. Details are in `docs/DECISIONS.md`.

1. **What "Stop after this Charleston" does.** Chosen: it skips the *second* Charleston once the first three passes are done (the tracker then reads "Pass 1 of 4"), rather than jumping straight to the courtesy pass, because the first Charleston is required.
2. **Where the Charleston card sits.** Chosen: under the rack (not above it), so the tiles stay on the first screen with the picker open.
3. **Scout titles.** Chosen: "Right player's exposed sets" rather than "Right's exposed sets".
4. **Scoring rows in the rule book.** Chosen: the second line (the choice in words) is shown only for custom rules, blanks and switched-off rules, because the built-in titles already say it ("A jokerless hand pays double").
5. **Blanks.** Chosen: the Blank key sits on its own row with a caption; a blank is never suggested for a pass or discard, so the rule's "may be passed in the Charleston" option is stored and shown but changes nothing.
6. **Comments in QR codes.** Chosen: a card's comments go into its QR code if they fit; if not, the code is made without them and the sheet says so. A card still too big is offered as a file.
7. **Tile styles.** Chosen: Traditional dots and bams carry a tiny index numeral (real sets do not) so they stay readable at the small size.
8. **Card QR link format.** Chosen: raw DEFLATE (what Foundation's `.zlib` writes) rather than a zlib-wrapped stream.

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
