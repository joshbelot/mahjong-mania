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

## 2026-10-16, §17.2 (Phase 13): opponent titles read "<Right> player's exposed sets"

The spec title "<Right>'s exposed sets" gives "Across's exposed sets", which reads badly aloud. The Scout card title is "<Seat> player's exposed sets" ("Right player's", "Across player's", "Left player's"). The sheet title when adding for an opponent uses the same words. The set-size choice in the add sheet is a row of chips instead of a segmented control so "6 · Sextet" never truncates at large text sizes (identifiers `exposure.size.3`…`6`). A `-UITestTab game|helper|cards|learn` launch argument (with `-UITestResetData`) was added so screens can be opened directly for simulator checks.

## 2026-10-16, §17.3 (Phase 14): Charleston details the spec left open

- **"Stop after this Charleston"** sets a flag (`CharlestonState.skipSecond`) so the second Charleston is skipped when the first three passes finish, instead of jumping at once. The first Charleston is required, so skipping its remaining passes would be wrong. The tracker then reads "Pass 1 of 4" (3 + courtesy). The button is hidden when nothing follows the first Charleston.
- `LockedPass` also stores each tile's `reasons` and the `focus` sections, so the list keeps the same wording while locked (the spec's struct had only the tiles).
- `setRack` and `clearRack` (random deal, Clear) drop the lock without moving the pass number; only a real swap (rack back at full size with at least one tile out and one in) advances.
- Lock tracking only runs in Charleston mode. In Peek the "Suggest a pass" button reappears for each new pass; in Coach the next suggestion is locked automatically.
- The Charleston card (East switch, tracker, buttons) sits under the rack, not above it: above the rack it pushed the tiles off the first screen when the picker was open. The "dealer starts with 14" explanation is the switch's VoiceOver hint rather than a second line of text.
- Until Phase 16 reads the rule book, the sequence is `CharlestonSequence.standard` (first, second, courtesy = 7 passes).
- `HelperDocument` now decodes every key with `decodeIfPresent`, so `helper.json` files from 1.0 still load.

## 2026-10-16, §17.4 (Phase 15): rule book core

- `RuleSet` keeps computed `discarderMultiplier`, `othersOnDiscardMultiplier`, `selfPickMultiplier`, `jokerlessMultiplier` and `jokerlessBonusForNoJokerLines` as views over `rules`, so v1 callers and tests still read naturally. Only `rules` is stored and encoded.
- A v1.0 rule set migrates every multiplier to an **enabled** rule with that multiple (even a multiplier of 1 or 0), which makes v1 and v2 payments equal for any v1 value (the 200-random-sets test proves it). A switched-off role rule counts as ×1; `pay.others` set to "Nothing" is multiple 0 and stays enabled.
- `MahjongInput` gained `lineSection` and `lineConcealed` (optional when decoding old hands) so "a hand from section …" and "a concealed hand" custom rules have something to test. Record hand fills them from the chosen card line.
- `Scoring.payments(for:seats:dealerID:rules:)`: `dealerID` is East for that hand; session logic passes each hand's own dealer when it recomputes, so "East wins" rules follow the rotation.
- Defaults for the optional built-ins (second Charleston, courtesy, blind pass, joker exchange, dead hand pays) are all on, as in the standard game; the thrower-pays-all rule and blanks start off.
- Rule choices are stored as `multiple` with the allowed values in `RuleDefinition.multipleChoices` (discarder 1–4, others 0–2, self-pick 1–3, jokerless 2–4). Old files may hold other numbers (the v1 editor allowed 1–10); they are kept and paid as written.

## 2026-10-16, §17.4 (Phase 16): rule book screens

- The old `RulesEditorView` is gone: `HouseRulesView` serves Settings, the new-game setup row and the scoreboard's rules sheet (same screen, same wording; the sheet still recomputes every hand).
- A scoring row's second line (its choice in words) is shown for custom rules, blanks and switched-off rules only. For the built-in scoring rules the title is already a sentence that says the choice ("A jokerless hand pays double"), so repeating it read as clutter.
- Rule titles follow the choice ("…pays triple"). The "How much" choices are offered as chips; a stored value outside the offered list (v1 allowed 1–10) is kept and shown as an extra chip.
- The Helper's Charleston tracker and the Learn "House rules explained" topic read the **default** rule book (Settings → House rules), since the Helper is not tied to a game night.
- Custom scoring rules can target a card section or a single hand; those pickers use the active card, and are hidden if it has none. The title fills in from the sentence until the user edits it.
- The payment explanation names applied custom rules ("House rule: …") and explains "the thrower pays for everyone".
- `Scoring.appliedCustomRules` was added to the core for that explanation.

## 2026-10-16, §17.5 (Phase 17): blanks

- `Tile.blank` reports `copies == 6` (the most any rule book allows); the rule's own count (2, 4 or 6) caps it in the picker and the store (`HelperStore.blankLimit`). `Tile.allCases` stays the 36 standard tile types (152 tiles) so card coverage and every older test are unchanged.
- The engine takes a `BlankPolicy` (only `swapForJoker`) instead of the whole rule book, so MahjongCore stays free of app settings. With a blank in the rack, a line is not called dead when the missing tile has been seen (it may still be in the discards); jokers count only if `swapForJoker`. Without the rule, or without a blank in the rack, nothing changes.
- A blank is never suggested for a pass or a discard whatever `passInCharleston` says, so that option is stored and shown but changes nothing in the Helper. The Learn Charleston drill deals standard tiles only, so there is no blank to select there either.
- The Blank key sits on its own row under the Joker row with a plain caption ("a spare tile with nothing on it"): a tenth key on the honours row would have shrunk the whole picker, and an empty tile with no words is not self-explanatory.
- Swap advice (Coach, holding a blank) lists up to 3 thrown tiles whose swap would bring the best line closer, in the Discard panel.
- `-UITestBlanks <n>` launch argument (with `-UITestResetData`) switches the rule on for UI tests.

## 2026-10-16, §17.6 (Phase 18): tile styles

- `TileView` reads the style from the environment (`\.tileStyle`, set once at the app root from `settings.tileStyle`); the Settings preview rows set it locally so every option shows itself.
- Traditional dots and bams also carry a tiny index numeral in the corner (real sets do not), so the count can be read at the small size; pips are nudged away from it. Winds show 東 南 西 北 with a small Latin letter.
- Large print spells the suit out (CRAK, BAM, DOT) and labels dragons, flower and joker with a word under a big letter or numeral.
- Modern puts number tiles on a suit-coloured face (red, green, blue) with a white numeral and a square (Cracks), triangle (Bams) or circle (Dots); honours reuse the Classic art on a neutral face. Blank is an empty ivory face in every style.
- The style screen lists the four styles as large selectable cards, each with its own preview row (Crack 1, Bam 5, Dot 9, East, Red Dragon, Soap, Flower, Joker, Blank when the blanks rule is on), in Settings under Appearance and feel.
- `-UITestTileStyle <style>` launch argument (with `-UITestResetData`) for UI tests and simulator checks.

## 2026-10-16, §17.7 (Phase 19): QR card sharing

- Compression is Foundation's `.zlib` algorithm, which writes **raw DEFLATE** (no zlib header or checksum). Anything that reads the link elsewhere must inflate with a raw-DEFLATE reader (Python: `zlib.decompress(data, -15)`). The same code reads and writes it on the phone, so nothing in the app is affected, and a link made with Python's raw DEFLATE is read by the app (the UI test uses one).
- The code carries the card's stored file text (comments included). If that is longer than 2,000 characters as a link, the code is made from the compact form without comments and the sheet says "Notes and comments in the card file aren't included, to keep the code small." Only if that is still too long does the sheet say the card is too big and offer the file share. (The spec only had the too-big case; comments bloated real cards enough to matter.)
- A link that arrives before onboarding finishes waits in `IncomingLinks` until the main screen is up. After a successful import from a link the new card opens in the Cards tab.
- "From a QR code picture" shows a plain message when the picture has no code, has a code that is not a card, or cannot be opened. Detection uses `CIDetector`; the Photos picker needs no permission.
- `-UITestOpenURL <url>` launch argument (with `-UITestResetData`) acts as if the link had opened the app.

## 2026-10-17, §18.3 (Phase 21): exercise engine details the spec left open

- **`ExerciseID` has a fourth field, `focus`** (default 0, optional when decoding). The curriculum's lessons narrow what a type asks about ("Winds & dragons" only asks about winds and dragons; "Colours mean suits" only uses lines with two suit colours; "Exposed vs concealed" mixes in the X/C question). A seed cannot carry that, so the ID does.
- **Extra answer kind `.decisions([Bool])`** for `keepOrPass` (one keep/pass per tile of `Exercise.queue`). `Grade` also carries `score`/`outOf` so Charleston and keep-or-pass show partial credit, and `Exercises.hint(for:card:)` supplies the lightbulb help (§18.5) so the lesson player has no engine knowledge.
- **`Exercise` also carries** `groups` (tiles in clusters, for hands where the grouping is the lesson), `lines` (not just one; `passThree` easy shows the two best), `queue`, `discard` and a `caption`.
- **Easy and normal deals are partly stacked.** Pick-a-Hand d1/d2 and Charleston d1 build the 13 tiles from 9 (d1) or 7 (d2) tiles of one hand of the card plus random tiles, then apply the §18.3.1 filter. A plain random deal is usually 8–9 tiles from every hand, which is the opposite of "clear-cut" for a beginner. Hard (d3) pickHand uses `Wall.deal(seed)` unchanged, so free play at Hard is today's drill and v1 grading is reproduced exactly (tested in `ExerciseCompatibilityTests`).
- **Pick-a-Hand d1/d2 are graded among the offered lines only**; d2 offers five lines with exactly one closest, d1 three lines from different sections at least two tiles further than the best.
- **Calling (`callIt`)** is graded by `checkCall` for the *shown* line, which is the engine's best line for the 13 tiles. A deal where another line would be best is rejected.
- **Test cost.** `ExerciseTests` runs 500 seeds for each of 13 types × 3 difficulties (about 80 s in a debug `swift test`); set `EXERCISE_SEEDS=20` for a quick run.

## 2026-10-17, §18.4–§18.6 (Phase 22): progress logic details the spec left open

- **Days are `LocalDay`, not `Date`.** A `Date` becomes a `LocalDay` (year-month-day, stored as `"2026-10-17"`) once, with the user's `Calendar`, and the streak, day log, review queue and Daily Deal then use whole-day arithmetic. That makes DST days (23 or 25 hours), midnight and a changed time zone harmless: past days never move, and a phone that goes back a day (a flight west) changes nothing.
- **Freezes are kept when they cannot save the streak.** With one freeze and two missed days the streak resets and the freeze stays (spending it for nothing felt like a penalty, §18.1). With enough freezes every missed day uses one.
- **A freeze is earned every 7th day of a streak** (7, 14, 21…) while fewer than two are held; the 7-day milestone therefore gives the first.
- **Combo and "On Fire".** The spec's "15 in a row in one lesson" cannot happen in a lesson of 5–10 questions, so the badge counts the best run in any lesson or Speed Round (`counters.bestCombo`); the per-lesson combo bonus (+5 per 5 in a row) is as specified. A right re-asked answer continues the run.
- **Stars.** Re-asked questions never count as misses; hints cost the third star but are not misses.
- **Lesson texts.** Every lesson has a one- or two-sentence intro (shown before the first question) so a beginner is told what a Pung or a Crack is before being asked; not in the spec, added under §18.1 ("fun in 30 seconds" needs a first question that can be answered).
- **Review node** asks 8 questions: due review items first, then the unit's questions at their hardest level. Units 1–2 have none (spec: after Unit 2). A review node counts as done once played.
- **Checkpoints** ask 7 questions from the unit's types at the hardest difficulty the unit uses, and 3 from earlier units (all 10 from the unit itself in Unit 1). They carry no lesson focus. A failed checkpoint still counts as a play toward the daily goal.
- **"Test out"** is offered on every unit that is not finished (not only locked ones), so a brand-new experienced player can test out of Unit 1 through the current unit. Testing out marks the unit and every earlier one tested out (stars already earned stay).
- **Daily Deal difficulty by weekday.** Monday to Wednesday are built around one hand (9, 8, 7 of the 13 tiles) so the best choice is clear; Thursday needs a clear best section, Friday any deal, Saturday a murky one (best section less than 2 tiles clearer), Sunday a murky deal whose best hand is 8+ tiles away. The pick is graded by the Pick-a-Hand rule (top three or tied), the pass squares are 🟩 as good as the engine's set, 🟥 a tile the best hand uses, 🟨 in between.
- **Daily Deal XP** is 25 per part (50), the Speed Round 2 per right answer; both count as one lesson for the daily goal.
- The whole state (`PracticeProgress`) and the rules that change it live in MahjongCore as a pure value type; the app's store (Phase 23) only loads and saves it.

## 2026-10-17, §18.2 and §18.4–§18.5 (Phase 23): Practice tab, path and lesson player

- **`practice.json` is flat**: `version` sits beside the fields of `PracticeProgress`, as §18.9 lists them. The store saves right after each finished play (a lesson is not worth losing to the 0.3 s debounce). The drills' best streaks move from `settings.json` to `freePlay` the first time 1.2 runs without a `practice.json`, and are zeroed in settings so they move once.
- **Skip in onboarding opens on Game and starts the path at Unit 1**; only an explicit choice on the new placement page sets the placement and, for "I'm new" and "I know the basics", the first tab (Practice). A skipper is saying "let me in", and the Game tab is where 1.1 users expect to land.
- **Lesson intros.** A teaching card (title, one or two sentences, and a row of labelled tiles for the first lessons) shows before the first question of a lesson that has never been finished, and not again once it has. Quitting before finishing does not count as finishing.
- **Choosing then Check; Yes/No and Keep/Pass commit on tap** (§18.5). In Keep or pass each tile gets its green or orange dot straight away; the one feedback sheet follows the fifth.
- **Re-asks** appear after the last planned question, once each, only in lessons and reviews (never in checkpoints, which are tests). A re-asked question that is missed again is not asked a third time.
- **"Test out"** sits on every unfinished unit's header. It asks the unit's checkpoint with an 8-of-10 bar and a confirmation first.
- **The header strip** is pinned above the path at normal text sizes and is the first item in the scroll at accessibility sizes, where a pinned strip would eat the screen.
- **UI-test hooks** (all need `-UITestResetData`): `-UITestPracticeSeed`, `-UITestRevealAnswers` (choice buttons get the value "correct" or "wrong"), `-UITestPlacement`, `-UITestToday`, `-UITestHour`, `-UITestPlayNode <id>` (opens a lesson at once, without its intro, for simulator checks). `-UITestTab practice` is accepted.
- The two drills stay as they were in 1.1, moved into Practice → Free play; Phase 26 rebuilds them on the exercise engine.

## 2026-10-17, §18.7 (Phase 24): feel

- **Sounds** come from `tools/make_sounds.py` (eight tones, 0.16–0.58 s, 16-bit mono WAV, standard library only) and play through `AVAudioPlayer` on an `.ambient` session with `mixWithOthers`. The new setting is Settings → Appearance and feel → Sound effects (default on). The silent switch mutes them.
- **Reduce Motion** is read from an app-level `\.reduceMotion` (the system setting, or `-UITestReduceMotion`) so both versions can be screenshotted by UI tests: it turns off confetti, shakes, pops, the next-node pulse, the floating XP and the combo burst; stars and celebrations fade in instead, and the check mark appears already drawn.
- **Celebrations** are full-screen, one at a time, after the completion screen: level up, each new badge, then the daily goal or a streak milestone. Both Continue and Play again go through them first, so a level-up is never skipped. The completion screen no longer lists them.
- **Combo.** A right answer that earns the combo bonus plays the combo arpeggio instead of the ding; the flame in the top bar bumps on every step and rings at 5, 10 and 15.
- **UI-test note.** XCUITest waits for the app to be idle, which includes the 2.2 s confetti, so a screenshot taken after waiting for a celebration screen usually misses the confetti; one taken straight after a tap catches it.

## 2026-10-18, §18.6 (Phase 25): goal, streak and profile details

- **The daily goal is asked after the first play** as the last screen of the celebration queue (after "Daily goal met", which uses the default Casual goal). Changing the goal, there or in Settings → Practice, never un-meets today: today stays counted and the header ring reads "Done for today"; the new goal applies from tomorrow. (Taking a streak day back would punish the player for choosing to aim higher.)
- **Streak news is shown inline, not in a pop-up.** A freeze that saved the streak, or a restart after a break, appears as a dismissible card at the top of the path when the Practice tab opens (and when the app returns to the front on a new day), with the spec's wording. Earned things (milestones, freezes earned, level-ups, badges, the goal) are the full-screen celebrations.
- **A milestone replaces the plain "goal met" screen** on the same day, so a 3-day streak is one celebration, not two. A freeze earned on a 7-day milestone is a second screen.
- **The profile** opens from the level badge or the flame in the header. The calendar is 12 weeks (Monday to Sunday columns ending this week), shaded by lessons that day; accuracy by skill counts questions right first time without a hint and shows "Not yet" until a skill has been asked.
- **Review nodes** show how many questions are waiting (from the review queue) as a small number on the node.
- **Test hooks:** `-UITestDayLog <days>`, `-UITestFreezes <n>`, `-UITestDailyGoal <goal>` (with `-UITestResetData`) set up a history; `PracticeProgress.recordDay` is what they call.

## 2026-10-18, §18.8 (Phase 26): Daily Deal, Speed Round, free play

- **The 1.1 drills are gone.** Free play now runs on the exercise engine (`pickHand` and `passThree`), with a card choice (Practice Card or, when it is not the Practice Card, your active card) and Easy/Normal/Hard (= difficulty 1/2/3). Hard Pick-a-Hand is exactly the v1 drill (same deals and grading, checked by `ExerciseCompatibilityTests` in the Phase 21 gate; that test and `DrillTests` were deleted with the old classes). The first deal of a launch can be pinned with `-UITestPracticeSeed`; later deals are random.
- **Free play pays 5 XP for a question right first time**, counts toward Sharp Eye and Charleston Champ, sends misses to the review queue, and keeps its own streak and best. It is not a lesson, so it does not move the daily goal or the streak.
- **Review mistakes** takes up to 10 due questions (most overdue first), re-asks them as they were, follows the spaced steps (+1, +3, +7 days) and counts as one lesson toward the goal. With nothing due it says so instead of opening an empty screen.
- **Daily Deal.** Both parts use the same 13 tiles (`DailyDeal.exercises`). The first finished play of the local day is the scored one (+25 per part, one lesson toward the goal, and the "Played today" state with a countdown to local midnight); later plays are labelled practice and pay nothing. The share text is generated after the play so it carries the streak as it stands; the Share button is a `ShareLink`.
- **Speed Round** unlocks when Unit 6 is finished (tested out counts). It asks single keep-or-pass questions, a new target every 5, and from the 21st question every 4th is a name-the-tile or name-the-group question. 60 s timed (+1 s right, -2 s wrong, never below 0) or, with Settings → Practice → "No timer in Speed Round", 30 untimed questions. The best score is the number right; both modes share it. It counts as one lesson toward the goal and pays 2 XP per right answer.
- **No feedback sheet in the Speed Round**: the last answer's reason sits under the next question, so the loop never stops. Right and wrong still get their haptic and sound.
- **Changed after playing the first lesson (Phase 26 branch):** the first lesson used to end with four full-screen taps in a row (level, badge, "daily goal met", "pick a goal"). The first time, the goal screen now stands in for "goal met": it says "Today's goal is done!" and asks for the real goal, so a new player gets three screens, not four.
- **Found by the gate:** the path scrolled to the next node on opening, which hid a streak message (freeze used, restart) above the screen. The path now stays at the top while such a message is waiting.


## 2026-10-30, §19.1 (Phase 28): harder, fairer questions

- **`nameTile` and `findTile` are gone**, and `tileFact` replaces them. A v1.2 review queue that holds either still loads: `ExerciseType` decodes both names as `tileFact` (the old seed picks a fact), so a saved `practice.json` never fails to open. The facts are in `TileFacts.swift`; each lesson part asks different facts where the pool allows (`Curriculum.fromParts` re-draws a seed whose fact it has already used).
- **Unit 1 is three lessons, not four** ("Suits and dragons", "Flowers, jokers and Soap", "Mixed"). `PracticeProgress` now has a `schema` (absent = 1.0 to 1.2). Loading an older file moves Unit 1's lessons once: old 1 and 2 merge into the new 1 (best stars, gold if either), old 3 into the new 2, old 4 into the new 3; the old `u1l4` entry is dropped. A test loads a 1.2-shaped file, checks the result, and checks that saving and loading again moves nothing a second time. Units 2 and up are untouched, and a finished Unit 1 stays finished (the checkpoint is its own node).
- **Facts that depend on the rule book.** Difficulty 3 "Mixed" tile facts can ask about the player's own table (blanks and the size of the set with them, what a blank can be swapped for, the second Charleston, the courtesy pass, joker exchange), but only when the lesson was started with the rule book (`Exercises.make(..., rules:)`; the lesson player passes the default rule set). The Daily Deal and Speed Round never pass one, so they stay the same for everybody. Blank facts appear only while the blanks rule is on.
- **Audit of every difficulty-1 lesson** (I played the questions of each node and asked "could someone who knows nothing about mahjong answer this by reading the screen?"). Found and fixed:
  1. `nameTile` ("What is this tile?" with the tile and its name printed) and `findTile` ("Tap the 3 Crack" with the numeral printed): replaced by `tileFact` for the whole unit.
  2. `groupName` listed its choices in order (Single, Pair, Pung, Kong), so the answer was always "the Nth choice for N tiles". Choices are now shuffled (test: the answer's position is not the tile count).
  3. Unit 2 lesson 1 (Sets) asked `groupName` at difficulty 1, which is only counting once the intro has said what a Pair is. It now uses difficulty 2 (jokers stand in the groups, so the player has to know the names *and* count the joker); Unit 3's first lesson is difficulty 2 and 3.
  4. The Speed Round's name-the-tile bonus used `nameTile`; it now uses `tileFact`.
  Checked and left alone because the answer is not on the screen: Which hand is this (compare tiles with a pattern), match-the-line, joker legal (needs the rule), how far (needs the count), needed tile, pick a hand, pass one, keep or pass, call it. The X / C badge on a line is a label, but "X means you may call" is the rule being taught, not something printed next to it. Left as known: Yes/No questions are always 50 percent guessable.
- **A mechanical test for every type** (`NotAnswerableFromTheScreenTests`): across all types, difficulties and focuses, the right choice's text never appears in the prompt or caption (or on a shown tile, for text choices), a numeric answer never appears as a number in the prompt, and Unit 1's lessons show no tiles at all.
- **Found by the gate:** the Speed Round's bonus question drew only text choices, so a number or Yes/No tile fact had no buttons ("No question 24" in `testSpeedRoundWithoutTheTimer`). The bonus now shows every kind of choice.
