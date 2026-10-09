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
