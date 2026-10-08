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
