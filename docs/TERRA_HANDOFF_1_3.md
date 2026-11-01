# Terra execution handoff: finish version 1.3

Prepared 2026-10-31. This is an execution prompt and a verified starting snapshot. Recheck Git/GitHub state before acting; another session may have progressed since this was written.

## Owner's instructions and authority

Finish the current version 1.3 wave from `docs/SPEC.md` §19. Reuse Claude's existing work, complete the remaining phases in order, and ship the completed wave to TestFlight automatically. You are authorized to make commits, push branches, open PRs, resolve conflicts, merge passing PRs, publish the specified support pages, and perform the real TestFlight upload. Do not stop at a plan or ask the owner to run the release command. Do not press Submit for Review: App Store submission is the owner's step.

For future waves, the owner's workflow is: the planning model scopes a wave and writes an explicit approved spec and execution prompt; the execution model implements it, completes the checks, merges the phases, and uploads the completed wave to TestFlight. A phase is one PR; a wave is the complete release. Do not upload after every individual phase. Do not invent another wave or broaden this one.

Read `AGENTS.md`, `CLAUDE.md` (which simply includes AGENTS), `docs/SPEC.md` §0 and §19, `docs/PROGRESS.md`, the latest entries of `docs/DECISIONS.md`, and `RELEASING.md`. Follow relevant earlier spec sections when referenced. AGENTS overrides obsolete CI instructions in older spec/handoff text: there is no CI, and it must remain disabled.

## Verified starting state

Repository: `/Users/joshbelot/Developer/mahjong-mania`, remote `https://github.com/joshbelot/mahjong-mania.git`.

On inspection, local and remote main were `d21dbcf59bfd667f0ac9025263e85852e144de40`. Version is still 1.2, build 4. The only new uncommitted file created by the planning session is this handoff; preserve it and include it in the Phase 31 PR. Do not discard it to make main clean.

| Phase | Actual state | Where |
|---|---|---|
| 28 Harder questions | Merged, PR #44 | main |
| 29 Cheat sheet and polish | Merged, PR #45 | main |
| 30 Bug squash | Merged, PR #46 | main |
| 31 Compliance and site | Implementation and docs committed locally; no PR or remote branch at inspection | `/Users/joshbelot/Developer/mm-p31`, branch `claude/app-store-compliance`, head `6088926`, previous commit `a1426e2` |
| 32 Listing package | Implementation, docs, and screenshots committed and pushed; no PR at inspection | `/Users/joshbelot/Developer/mm-p32`, branch `claude/app-store-listing`, head `bd0b5d4` |
| 33 QA and release | Not started | Create a branch after 31 and 32 merge |

Both pending phase branches started independently from `d21dbcf`; Phase 32 does not contain Phase 31. Expect conflicts in SPEC, PROGRESS, and DECISIONS when integrating. Preserve both sets of decisions and completed checkboxes. Main's progress table saying 31 and 32 are "not started" is stale. Branch docs saying "in PR" are also premature: GitHub had no such PRs.

Other checkouts exist (`mm-p29`, `mm-p30`, `mm-gate`, `mm-cov`, `mm-pages`). Preserve them. Use existing phase branches/checkouts where permissions permit. If the sandbox excludes a sibling checkout, request the proper filesystem access or continue that same branch in an allowed checkout after preserving its state; do not circumvent sandbox restrictions or delete another session's work. Keep the existing `claude/` names; use `claude/release-1-3` for Phase 33 unless it already exists.

The orphan `gh-pages` branch is already published at `7788d077b597aee006020cc44e714aab4528aa2e`. GitHub Pages API reported `built`, source `gh-pages:/`. Both pages returned HTTP 200 during this inspection:

- https://joshbelot.github.io/mahjong-mania/privacy.html
- https://joshbelot.github.io/mahjong-mania/support.html

Do not recreate the site or orphan branch. Check it still matches the app before release.

## Phase 31: finish and merge compliance

Existing changes add `App/Content/AppLinks.swift`, About links, the exact money wording in Settings/game setup/house rules, remove unused `ComingSoonView`, remove the UserDefaults required-reason manifest entry, and add app unit and UI compliance tests. Review and finish these changes rather than rebuilding them.

### Saved validation evidence and unresolved findings

- `/private/tmp/claude-p31a.log`: app unit run passed with 299 tests.
- `/private/tmp/claude-p31b.log`: the two selected compliance UI tests passed.
- `/private/tmp/claude-p31.log`: the later full gate includes 333 passing core tests. The Xcode result is `/Users/joshbelot/Developer/mm-p31/build/p31.xcresult`.
- `xcrun xcresulttool get test-results summary --path <result> --format json` reported **Passed, 413 tests, zero final failures, 414 test runs**. One test needed a retry. The console's initial "1 failure" is not the final result; the final `TEST SUCCEEDED` is supported by the result bundle.
- The initial failure was `HelperTests.testPlayingExposuresAndSeenTilesLight`, `AppUITests/HelperTests.swift:365`: "Tapping an exposure removes it". Investigate whether this is a real removal problem, hittability/timing, or simulator interference. Retain the removal assertion. Do not add blind sleeps or weaken it just to pass.
- The same result bundle has **three runtime warnings**, all "Invalid frame dimension (negative or non-finite)", in `CardsTests.testDuplicatePracticeCardEditLineAndSave`, `testImportAndEditDark`, and `testImportAndEditLight`. This contradicts an assumption that the latest gate is warning free. Reproduce, locate the responsible layout calculation, fix the cause, and add the lowest appropriate regression coverage. Log behavior changes in DECISIONS. Do not suppress the diagnostics.

Resolve these limited release blockers in the Phase 31 PR as an explicit continuation of the final compliance/completeness check, recording this scope addition. If investigation reveals a substantial redesign, stop that expansion and report the specific decision needed.

Re-audit the privacy manifest against actual required-reason API use and current Apple documentation. The existing unit test merely pins an empty declaration; it is not proof that no APIs need declarations. Preserve truthful privacy answers. Search app/core sources and relevant dependencies, not just UserDefaults strings. Inspect changed UI in the simulator in light, dark, and AX5, and capture screenshots. Verify About links actually open their intended destinations and the money subtitle fits.

Add a concise standing-workflow note to AGENTS in this PR: approved waves are planned/spec'd first and executed phase by phase; the owner authorizes commit/push/PR/merge and automatic TestFlight release after all wave phases and gates pass; physical-device checks and Submit for Review remain owner steps. Keep CLAUDE's include relationship. This records the owner's instructions from this handoff for future sessions.

Run `tools/test.sh` on the final Phase 31 branch, inspect compiler and runtime diagnostics, and preserve the result bundle and log. The script already runs `swift test --package-path Packages/MahjongCore`; report that fact rather than duplicating it without a reason. Tick §19.9 and update PROGRESS/DECISIONS in this PR. Push, create the PR, attach it to the Codex chat if supported, and merge when local gates pass. Record exact commands, results, warning counts, and screenshot evidence in the PR. No CI gate exists.

## Phase 32: integrate and finish the listing

Bring merged main into the existing Phase 32 branch. Resolve documentation conflicts so Phase 31 stays complete. Include its current PR number/status and both decisions entries.

Existing artifacts to reuse:

- `AppStore/metadata.md`, `review-notes.md`, `age-rating.md`, `app-privacy.md`, `checklist.md`.
- Eight `1320 × 2868` screenshots in `AppStore/screenshots/6.9/`.
- Optional eight `1284 × 2778` images in `screenshots/6.5/`, currently scaled from the large set. They are not native captures; accurately disclose that deviation, or omit the optional set if unnecessary.
- `AppUITests/AppStoreScreenshotTests.swift` and `tools/app_store_screenshots.sh`.
- `tools/check_listing.py`; run `python3 tools/check_listing.py` and include its actual output in the PR.

Claude's saved listing output `/private/tmp/claude-listing.txt` says name 24/30, subtitle 27/30, promotion 161/170, description 2126/4000, keywords 94/100, What's New 284/4000. Rerun after edits; these numbers are historical evidence.

Regenerate the screenshots on the integrated branch using the existing script, inspect every image visually, and confirm eight files, exact dimensions, light mode, clean 9:41 status bar, full battery, only the original Practice Card, and realistic demo data. Retain the fixed date/seed. Use stable accessibility identifiers rather than the Helper screenshot's current arbitrary coordinate tap where practical. The inspected Helper image shows closest hands but also "Discard suggestions need your full 14 tiles"; improve the capture to show useful results prominently, without changing the app's feature behavior or fabricating UI. Assert the intended capture state and fail if PNG writing fails; the current `try?` writes can silently omit output. Optional screenshots must be current too if delivered.

Recheck the listing's claims against implemented behavior and the integrated compliance wording. Consult current primary Apple documentation for the age-rating/privacy questionnaires; remove blanket advice to answer any unfamiliar question "No/None". State exact supported answers and have the owner assess new questions honestly. Treat 4+ as an expectation, not a guaranteed Apple outcome. Keep trader status, personal review contact information, countries, final submission, and other explicitly owner-only choices as owner steps. Do not fill them in or publish personal contact information.

Inspect changed/captured screens as required. Run the complete local gate on the final integrated branch (this phase adds executable UI test code, so it is not docs-only), inspect diagnostics, then push, open/attach/merge its own PR. Tick the listing checkbox and update PROGRESS/DECISIONS in the same PR.

## Phase 33: final QA, then automatic TestFlight release

Start from main after 31 and 32 merge. Work on a dedicated phase branch/PR.

1. Complete §19.9 Phase 33 simulator QA using existing tests/flows: beginner through Unit 2, experienced test-out, complete Game Night, Helper, Cards including QR, and existing §13/§17/§18 coverage. Cover iPhone and iPad compatibility mode. Inspect screenshots rather than relying on tests alone. Select actual available simulator destinations; test targets are `MahjongManiaTests` and `MahjongManiaUITests` (for example `-only-testing:MahjongManiaUITests/ComplianceUITests`). Follow the generated project for exact names.
2. Set `MARKETING_VERSION` to `"1.3"` in `project.yml`. Leave build numbering to the uploader (currently 4; normally next is 5, but recheck App Store Connect). Run XcodeGen; never commit `.xcodeproj`.
3. Update `TestFlight/WhatToTest.txt`, prepend an accurate 1.3 section to `docs/RELEASE_HANDOFF.md`, and link the prepared AppStore checklist. Preserve older release history but clearly mark obsolete CI/setup claims as historical.
4. Address the release script's artifact lifetime before using it: `tools/upload_testflight.sh` currently creates a temporary worktree and deletes it on exit, including the dry-run IPA. The repo requires validating that exported IPA before the real upload. Add an optional `--ipa-output <absolute-path>` argument for `--dry-run` that copies exactly one exported IPA to that explicit external path before cleanup. Reject an existing destination or missing parent directory, reject this option without `--dry-run`, preserve existing behavior when absent, and update usage and RELEASING. Keep signed artifacts/logs outside Git. Verify parsing/error paths without printing secrets, and exercise the actual export in the final dry run. Do not disable cleanup or either test gate.
5. Run the full gate on the final branch, check zero compiler/runtime warnings, record exact evidence, open/attach/merge the Phase 33 PR. Mark QA and preparation complete, but leave upload pending until it really happens. The historical full Phase 31 run took about 90 minutes: let tests finish and provide useful progress updates; do not assume a long UI run is hung or run competing suites on the same simulator.
6. From clean, up-to-date main with all wave changes merged, use `zsh -ic` for signing variables. Choose a fresh explicit IPA destination in an existing private temporary directory and run `tools/upload_testflight.sh --dry-run --ipa-output <absolute-path>` in that shell.
7. Validate the preserved IPA using `xcrun altool --validate-app -f <absolute-path> -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"` inside `zsh -ic`. Keep authentication values, raw signing logs, private keys, JWTs, and environment dumps out of tool output and Git. Capture/redact tool diagnostics if they expose identifiers. Fix genuine validation problems through a tested PR, merge, and repeat validation. Never change privacy declarations speculatively just to silence a validator.
8. Run the real `zsh -ic 'tools/upload_testflight.sh'` without asking the owner again. It intentionally runs its own tests, increments the build, uploads, and records the bump. Preserve that behavior. If main protection causes a `release/build-N` branch instead, open/attach/merge its bump PR before another release.
9. Check App Store Connect processing for this exact app, version, and build via authenticated API or available connector, using existing local signing setup without displaying credentials. Wait for `VALID` with sensible backoff. An accepted upload is not yet a processed build. If it fails, investigate and fix; if it is still processing when you must hand back, explicitly report that state rather than claiming completion. Use the product's monitoring tool if continued follow-up is required.
10. Once VALID, record version/build, merged PRs, QA evidence, and processing outcome in PROGRESS/DECISIONS (docs-only main updates are permitted there). Tick the release checkbox only on evidence. Keep physical iPhone, haptics, manual VoiceOver, real-device speed, installing TestFlight, and final App Store submission boxes unticked for the owner.

## Constraints and completion report

Native Swift 6/SwiftUI, iOS 17+, Foundation-only MahjongCore. No Expo/React Native/JS app. No generated project commits. No CI activation, workflow dispatch, or waiting for GitHub Actions. Do not remove assertions, skip failing tests, fabricate screenshot evidence, or claim warnings are clean from exit status alone. Preserve unrelated edits and all existing worktrees. Request actual sandbox escalation when needed rather than abandoning authorized work.

Work through the sequence without asking permission between phases. Ask only for a real product decision or missing access you cannot resolve; include the concrete blocker. Routine implementation details and the real upload are already authorized.

Final report: merged PR links; shipped version/build and App Store Connect processing status; concise local validation and warning results; links to the App Store listing/checklist; remaining owner/device/submission actions. If blocked, state exactly what completed and what remains. Do not call the wave shipped without the actual upload and processing evidence.
