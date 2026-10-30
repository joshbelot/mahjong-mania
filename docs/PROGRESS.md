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

## Version 1.3 (current work)

Plan: `docs/SPEC.md` §19 (first App Store release). v1.2 build 4 is on TestFlight (2026-10-18). One PR per phase, in order; ship to TestFlight when all are merged; the owner submits for review.

| Phase | Status | PR |
|---|---|---|
| 28 Harder, fairer questions | merged | [#44](https://github.com/joshbelot/mahjong-mania/pull/44) |
| 29 Cheat sheet and practice polish | not started | |
| 30 Bug squash | not started | |
| 31 Compliance in the app and the website | not started | |
| 32 App Store listing package | not started | |
| 33 1.3 QA and TestFlight upload | not started | |

### 1.3 bug log

| Area | Symptom | Cause | Fix | PR |
|---|---|---|---|---|

### Open questions for the owner (1.3)

_None yet._

## Version 1.2 (done)

Plan: `docs/SPEC.md` §18 (Practice becomes a game). v1.1 build 3 is on TestFlight (2026-10-16). One PR per phase, in order; ship to TestFlight when all are merged (§18.11).

| Phase | Status | PR |
|---|---|---|
| 21 Exercise engine (MahjongCore) | merged | [#36](https://github.com/joshbelot/mahjong-mania/pull/36) |
| 22 Progress logic (MahjongCore) | merged | [#37](https://github.com/joshbelot/mahjong-mania/pull/37) |
| 23 Practice tab, path and lesson player | merged | [#42](https://github.com/joshbelot/mahjong-mania/pull/42) (replaced #38) |
| 24 Feel: animation, haptics, sound | merged | [#39](https://github.com/joshbelot/mahjong-mania/pull/39) |
| 25 Daily goal, streaks, badges, profile | merged | [#40](https://github.com/joshbelot/mahjong-mania/pull/40) |
| 26 Daily Deal, Speed Round, free play | merged | [#41](https://github.com/joshbelot/mahjong-mania/pull/41) |
| 27 1.2 QA and TestFlight upload | merged; **1.2 (4) uploaded and processed** | [#43](https://github.com/joshbelot/mahjong-mania/pull/43) |

### Open questions for the owner (1.2)

Product judgements the spec did not settle. Each choice is the one that best fits §18.1; any can be changed. Details are in `docs/DECISIONS.md`.

1. **Skip in onboarding.** Chosen: Skip opens on Game and starts the path at Unit 1; only an explicit placement choice opens on Practice ("I'm new", "I know the basics") or Game ("I play regularly").
2. **Lesson intros.** Chosen: every lesson that has never been finished opens with a short teaching card (and labelled tiles for the first lessons) before its first question, so a beginner is told what a Pung or a Crack is before being asked. The spec has no intro.
3. **Where "Test out" lives.** Chosen: on every unfinished unit's header (not only locked units' checkpoints), so a new experienced player can skip several units at once. Pass mark 8 of 10, a confirmation first.
4. **Easy and normal deals are partly stacked.** Chosen: Pick-a-Hand d1/d2 and Charleston d1 build the 13 tiles around one hand of the card, then apply the §18.3.1 filter, because a random deal is rarely "clear-cut". Hard is today's random deal.
5. **Changing the daily goal never un-meets today.** Chosen: today stays counted and the new goal applies from tomorrow; the goal is asked as the last of the first lesson's screens, and replaces the separate "goal met" screen that time.
6. **Freezes when they can't save the streak.** Chosen: with two missed days and one freeze the streak restarts and the freeze is kept (no punishment for a loss that could not be prevented).
7. **"On Fire" (15 in a row).** Chosen: counted over any lesson or Speed Round, because a lesson has at most 10 questions.
8. **Daily Deal difficulty by weekday.** Chosen: Monday to Wednesday are built around one hand so the best choice shows; Thursday needs a clear best section; Friday is any deal; Saturday and Sunday are murky deals (Sunday's best hand is 8+ tiles away). Replays are practice and pay nothing.
9. **Speed Round.** Chosen: single keep-or-pass questions with a new target every 5, bonus name-the-tile / name-the-group questions from the 21st; the reason for the last answer sits under the next question instead of a feedback sheet; both modes (60 s, or 30 untimed) share one personal best.
10. **Free play and Review mistakes.** Chosen: free play pays 5 XP per right-first-time question, counts for the Sharp Eye and Charleston Champ badges, and does not touch the streak; "Review mistakes" counts as one lesson toward the daily goal. A miss on your own card is not queued for review.
11. **Celebrations.** Chosen: full-screen, one at a time, after the completion screen (level, each badge, then goal or milestone); Continue and Play again both go through them. A new player sees three screens after their first lesson.

### 1.2 release (2026-10-18)

From a clean `main` at `4aeb26a`: `zsh -ic 'tools/upload_testflight.sh --dry-run'` passed (tests, archive, export; build number unchanged). The exported `.ipa` was validated with `xcrun altool --validate-app` ("VERIFY SUCCEEDED with no errors"; version 1.2, URL scheme present, no `*UsageDescription` keys). The real upload ran the tests again, bumped the build, uploaded **Mahjong Mania 1.2 (4)** and pushed "Bump build to 4". App Store Connect (API) lists build 4 for version 1.2 with processing state **VALID** about 17 minutes after upload. Owner steps left: paste `TestFlight/WhatToTest.txt` as the build's "What to Test", add testers if needed, and install it on a real iPhone.

### 1.2 QA pass (2026-10-18, iPhone 17 Pro and iPhone Air simulators, iOS 27 SDK)

- **Every phase** was built, driven and looked at in the simulator in light, dark and the first accessibility size before it merged, and every PR's `tools/test.sh` was run locally on its branch head. The gates found and fixed: a streak message hidden by the path's auto-scroll, a wrong-order unit test, and three flaky UI tests; one run also failed from a nearly full disk (a simulator launch error, not a test failure) and was simply rerun.
- **Beginner:** `PracticeQATests.testBeginnerPlaysThroughUnitTwo` plays a fresh install through Units 1 and 2 (all eight lessons and both checkpoints, with mistakes and a hint), shown unlocking Unit 3. **Experienced:** `testExperiencedPlayerTestsOutOfThreeUnits` tests out of Units 1-3 at once. `PracticeScreensTests` opens a lesson of every question type in light, dark and AX; the Daily Deal, Speed Round, free play, review, streak and profile tests add the rest. Reduce Motion on and off is covered for the lesson and its celebrations.
- **Existing §13 and §17 checks** still pass: they are the rest of the UI suite (Game Night, Helper, Cards, QR, Learn, Settings, large text), which ran green in the same gates.
- **Not verifiable here, owner steps (boxes left open):** haptics and sounds on a real phone (and the silent switch), VoiceOver by hand through a lesson and the path, real midnight and time-zone changes on a device, sharing the Daily Deal into Messages, real-device speed, and installing the TestFlight build.

## Version 1.1 (done)

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
| 20 1.1 QA and TestFlight upload | merged; **1.1 (3) uploaded and processed** | [#34](https://github.com/joshbelot/mahjong-mania/pull/34) |

### 1.1 release (2026-10-16)

From a clean `main` at `15d7925`: `zsh -ic 'tools/upload_testflight.sh --dry-run'` passed (tests, archive, export; build number unchanged). The exported `.ipa` was then validated with `xcrun altool --validate-app` ("VERIFY SUCCEEDED with no errors"; version 1.1, URL scheme `mahjongmania` present, no `*UsageDescription` keys). The real upload `zsh -ic 'tools/upload_testflight.sh'` ran the tests again, bumped the build, uploaded **Mahjong Mania 1.1 (3)** and pushed "Bump build to 3". App Store Connect (App Store Connect API) lists build 3 for version 1.1 with processing state **VALID** at about 11 minutes after upload. Owner steps left: paste `TestFlight/WhatToTest.txt` as the build's "What to Test", add testers to the build if needed, and install it on a real iPhone.

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
