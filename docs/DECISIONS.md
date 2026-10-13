# Decisions log

Deviations from, or clarifications of, `docs/SPEC.md`. Newest last. Format: date, spec section, what changed and why.

## 2026-10-08, §6.4 / §16.2 (Phase 0): display name and category also in `info.properties`

`INFOPLIST_KEY_*` build settings only take effect when Xcode generates the Info.plist. Because the spec has XcodeGen generate `App/Info.plist`, those two settings alone would be ignored, so `CFBundleDisplayName` and `LSApplicationCategoryType` are also listed under `info.properties`. The `INFOPLIST_KEY_*` entries stay as in the spec.

## 2026-10-08, §6.4 (Phase 0): test targets get `GENERATE_INFOPLIST_FILE` and bundle IDs

The unit-test and UI-test bundles need an Info.plist to be signed/loaded; `GENERATE_INFOPLIST_FILE: YES` and explicit `PRODUCT_BUNDLE_IDENTIFIER`s (`…mahjongmania.tests`, `…uitests`) were added in `project.yml`.

## 2026-10-08, §14.2 (Phase 0): CI details

- Simulator choice is done by `tools/simulator_id.sh` (newest available non-SE iPhone) instead of a hard-coded name, as the spec allows.
- The `ios` job additionally builds an unsigned Release archive and fails if the archived Info.plist contains `*UsageDescription` / `UIBackgroundModes` or an `*.entitlements` file exists. This checks the Phase 0 "no permissions/entitlements" acceptance box on every run.

## 2026-10-08, environment: no local Swift toolchain

The authoring sandbox is Linux with no Swift 6 toolchain, and `download.swift.org` is blocked by the network policy. The `core` CI job (`swift:6.0` container) is therefore the only place `MahjongCore` tests run, and the `ios` CI job is the only place the app builds.

## 2026-10-08, §13 Phase 3 test list: `Triple Year` expands to 2 targets, not 4

The spec expected 4 targets (x ∈ {Cracks, Bams} × 2 orderings of y/z), but §10.1 step 6 also requires deduping targets with the same multiset, and swapping y and z in `2026/x 2026/y 2026/z DD/x` gives an identical hand. Keeping the dedupe (it is what keeps `analyze` fast and the result lists free of duplicates) gives 2 targets. SPEC §13 Phase 3 updated.

## 2026-10-08, §10.2 / §10.4: `liveOuts` adds live jokers only when a joker-able shortfall remains

The spec says to add live jokers to `liveOuts` "if any jokerOK deficit". When rack jokers already cover every joker-able deficit there is nothing left to collect, so live jokers are only added while a joker-able shortfall remains (the `jokerOK: true` entries of `missing`).

## 2026-10-08, §9.4 / §7.2: `CardLine.indexInSection`, `CardLine.source` and auto IDs

`CardLine` gained a stored `indexInSection` (1-based; set by the card parser) because `displayName` needs it. `CardLine.source` is the canonical serialisation, so `parseLine(serialize(line))` equals `line` exactly. `parseLine` without an `id` derives one from the canonical source (`L_<fnv1a>`); `parseCardFile` uses the spec's `L<index>_<fnv1a>`.

## 2026-10-08, §1 Phase 1: shuffle is implemented with `SeededRandom` directly

The spec suggests the stdlib's `shuffled(using:)`. Its algorithm is not guaranteed to be stable across Swift versions, which would silently change "Try again" replays and any golden test. `SeededRandom.shuffled(_:seed:)` is a plain Fisher–Yates driven only by SplitMix64, so a seed always gives the same deal. SplitMix64 is tested against reference vectors.

## 2026-10-08, §7.3: `Binding` renamed to `SuitBinding`

MahjongCore's `Binding` (suit assignment + shift of a target) clashes with `SwiftUI.Binding` in every app file that imports both (compile error "cannot specialize non-generic type 'Binding'"). The core type is `SuitBinding`; its fields are unchanged (`x`, `y`, `z`, `k`). SPEC §7.3 updated.

## 2026-10-09, §11.7 / §13 Phase 11 (Learn drills, onboarding, content)

- Pick-a-Hand counts a pick as right if it is in the top 3 or ties the third line's distance (strict top-3 would mark an equally close line wrong). Only the first answer to a deal moves the streak, so "Try again" can't farm it.
- Charleston streak grows only on 3 of 3 and resets otherwise; when several copies of one tile are passed, the lowest-utility copies count.
- `-UITestDrillSeed <n>` launch argument fixes the first drill deal; `-UITestShowOnboarding` wipes data but leaves onboarding on.
- "I'll enter my own card" on onboarding page 3 keeps the Practice Card active and shows a hint to open Cards → New (no tab-selection binding exists yet).
- `LearnSection` has an `id`, `LearnTopic` has a `summary`, and `LearnBlock` is not `Identifiable` (views use `enumerated()`). Glossary terms use the exact strings `Concealed (C)`, `Exposed (X)`, `East (Dealer)`, `Family (Section)`, `Joker exchange`.

## 2026-10-09, §11.5 / §11.2 (Phase 6 design system)

- Added the `tileInk` token (winds need dark ink on the ivory face in dark mode) and `Typography.pattern`.
- `.missing` tiles also show a faint ghost face (a bare dashed box was unreadable in dark mode).
- `TileRackView.onRemove` takes a `Tile` (remove one copy), not an index; `TileKeyboardView.limit` is an optional cap on the total of `usage`.
- Settings is a full-height sheet (`.large` only) because it pushes screens.

## 2026-10-09, CI

The `ios` job's UI suite grows with each phase (about 20 minutes by Phase 11). The test step retries failing tests once (`-retry-tests-on-failure`); the last step prints a failure summary; screenshots are published to the `ci-screenshots` branch.

## 2026-10-09, §11.7 Cards (Phase 8)

- "Practise this hand" calls `HelperStore.pin(lineID:)`, sets `settings.activeCardID` to the line's card, and switches to the Helper tab (the pinned line is resolved in the active card).
- `RootView` owns tab selection (`AppTab`, `\.tabSwitcher`) and the Cards navigation path (`\.cardsNavigator`); mixing item destinations with value links made Line detail unreachable in UI tests.
- The key row appends at the end of the notation (no cursor API on iOS 17). Editing a hand rewrites the card text via parse → change → `Notation.serialize`, so comments and invalid lines in a user card are dropped then; imports keep valid lines only.
- The import destination picker is a plain "New card" label when no user cards exist.

## 2026-10-09, §11.7 Game Night (Phase 9)

- Session setup turns into the scoreboard in place (`NewGameView`) and End game night swaps to the summary in place (`GameSessionView`), so no `NavigationPath` is needed; Back returns to the Game tab.
- "How?" starts unselected with two chips (Self-pick / Discard) instead of a segmented picker, so Discard is a real tap in the 5-tap path. The adjustment sheet is `.large` only (medium detent taps were unreliable in UI tests).
- The scoreboard uses a local `ScorePointsText` (the shared `PointsText` has no large size). Self-pick explanation wording is new: "Others pay 50 (self-pick)" / "Base 25. Bea drew the winning tile, so everyone else pays double (50). Bea collects 150."
- Rules editor: "Use as default" writes `settings.defaultRules`, "Save ruleset" appends to `settings.savedRules`.

## 2026-10-09, §11.7 Hand Helper (Phase 10)

- Charleston rack limit is 14 (the dealer holds 14); the keyboard still auto-collapses at 13.
- The Assist chip offers Peek and Coach only; Off stays in Settings (choosing it in the Helper would hide the tab you are on). If the Helper tab disappears while selected, the app falls back to Game.
- The Coach panel sits above the results list. Discard suggestions need all 14 tiles (rack plus exposures), otherwise a hint is shown.
- "Could be going for" shows line names only; the Scout "why" is "Fits N of <opponent>'s possible hands". Peek shows the top 3 hands without "Show all"; Coach shows 8 with "Show all". A pinned line has an "Unpin this hand" button.
- The exposure sheet is large-detent only. UI-test launch arguments `-UITestHelperRack`, `-UITestHelperMode`, `-UITestAssist` are honoured only with `-UITestResetData`.

## 2026-10-13, §11.7 Cards (stabilisation item 7): edits change only the affected line of the card text

This reverses the Phase 8 note that editing a hand rewrites the whole card text and drops comments and invalid lines. `CardEditing` now edits the stored text itself: it uses the new `CardFileParseResult.sourceLineNumbers` to replace or remove just the edited line, and inserts a new line after the last line of its section (or in a new `# Section` at the end). Comments, blank lines, section order and lines that do not parse stay as the user wrote them. Moving a hand to another section appends it to that section. Line IDs still contain the line's index, so adding or removing a hand renumbers the IDs of the hands after it (unchanged, per §9.5).

## 2026-10-13, §11.7 Hand Helper responsiveness (stabilisation item 5)

Analysis stays on the main actor. Measured per tile tap for a full 14-tile rack (60 seeded deals) on an Apple-silicon Mac: Release max 4.4 ms (closest hands 0.3 ms, pass advice 0.3 ms, discard advice 3.5 ms; with three opponents' exposures scouted, discard advice 1.3 ms), Debug max 66 ms. That is far below the 50 ms goal in a Release build, so moving it off the main actor would add concurrency complexity for no visible gain. `HelperTimingTests` keeps a loose 250 ms bound as a regression guard.

## 2026-10-13, §14.2 / §14.3: CI disabled by the owner

The GitHub Actions workflow is disabled (the `ios` job took 25–90 minutes per run) and stays off. `.github/workflows/ci.yml` is kept only for reference. The definition of done is now: `tools/test.sh` passes locally on the owner's Mac (core tests, app unit tests, UI tests), there are no compiler warnings, and new UI has been looked at in the simulator. Wherever the spec says "CI is green", read "the local run is green".

## 2026-10-13, §11.2 Large text (stabilisation item 3)

Custom rows no longer squeeze at accessibility text sizes: `AdaptiveStack` turns a row into a column and `AdaptiveLabelStyle` drops the icon in buttons, so names, scores and labels wrap by word instead of truncating. Applied to the scoreboard, hand log, summary, players, seat setup, card rows, Helper header, rack header and result cards. `LargeTextTests` runs the Cards and Game flows at AX5 in light and dark. The system segmented picker for the Helper mode does not scale with text size; left as is.

## 2026-10-13, §4.1 / §4.3 small decisions (owner: choose by best practice and consistency)

- Active players have unique names, ignoring case. Typing an existing name in the game setup selects that player instead of adding a twin; the Players list ignores a duplicate add; rename to a taken name is ignored. Archived players do not count.
- Share card shares a text file named after the card (`CardFileExport`, "Club Card.txt"); copy and message targets still receive the plain text.
- Toggling "Keep screen awake" applies at once on the scoreboard.
- Import keeps skipping lines that do not parse; the Check step lists them before anything is imported.

## 2026-10-13, §9.5 Line IDs no longer contain the line's position

`L<index>_<hash>` became `L_<hash>` (plus `_2`, `_3` for identical lines). With the index in the ID, adding or deleting a hand renumbered the IDs of every hand after it, so per-hand win counts, "Practise this hand" pins and the line recorded with a hand could silently point at another hand. IDs now change only when the hand's own text (notation, points, name, X/C, shift) changes. Done before the first release so no session data exists with the old format.

## 2026-10-13, §6.4 / §8: `UIRequiresFullScreen` added

The first real upload was rejected by App Store Connect ("Invalid bundle … you need to include all of the … orientations to support iPad multitasking") even with `TARGETED_DEVICE_FAMILY = 1`; the dry run cannot catch this because the check runs on Apple's side. `UIRequiresFullScreen: true` in `project.yml` keeps the app portrait-only and passes validation (checked with `xcrun altool --validate-app` on a signed export before uploading).
