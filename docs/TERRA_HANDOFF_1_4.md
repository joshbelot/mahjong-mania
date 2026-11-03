# Terra execution prompt: version 1.4 beginner clarity

**Ready to execute, 2026-11-01:** version **1.3 build 5** is recorded as `VALID`; release PRs #47–49 and release-record PR #50 are merged. This prompt authorizes implementation and release of 1.4 only. The conditional scanner specification is prepared for a separate wave.

---

Work in `/Users/joshbelot/Developer/mahjong-mania`. Implement the approved **version 1.4 beginner clarity wave, phases 34–38**, from `docs/NEXT_WAVES_SPEC.md`. Read that entire document for boundaries; implement only its 1.4 requirements now. Do not stop at another plan or a list of suggestions.

## Authority and starting gate

The owner authorizes commits, pushes, PR creation, conflict resolution, merges, and **automatic TestFlight upload when all phases of this wave are merged and the local gates pass**. Continue phase by phase without asking permission again. Never press Submit for Review; the owner performs App Store submission and physical-device checks.

First read `AGENTS.md`, `CLAUDE.md`, `docs/SPEC.md` §0 and relevant existing architecture sections, `docs/NEXT_WAVES_SPEC.md`, `docs/PROGRESS.md`, recent `docs/DECISIONS.md`, and `RELEASING.md`. Existing source and the integrated 1.3 state take precedence over the old baseline snapshot in the planning evidence. Keep CI disabled; old SPEC text about waiting for CI is obsolete.

Verify 1.3 phases 28–33 really merged, the correct version/build uploaded, and App Store Connect processing is `VALID`. Use current release records and authenticated read-only status if necessary. Do not start 1.4 implementation while another session is finishing 1.3 or uploading from main. If 1.3 is incomplete, report its exact remaining step and leave this work ready; do not race or take over that executor's simulator/release.

The starting gate has been checked: GitHub main was `2cf27b082e27a71cf80f15d08ad37df239378a7d`, and its merged PROGRESS/release record reports 1.3 (5) VALID. The original workspace remains on `claude/release-1-3` at `5fb527b`; main is checked out separately at `/private/tmp/terra-release-main`. Recheck `git worktree list`, fetch current remote refs, then create/reuse the Phase 34 branch from current main in a suitable checkout. Preserve the untracked planning files below; do not implement on the stale 1.3 branch, forcibly move an occupied main branch, or redo the completed release. Read the completed release records from current main rather than treating the original workspace's stale progress table as evidence that 1.3 is unfinished.

Planning files may still be untracked: `docs/NEXT_WAVES_SPEC.md`, this handoff, the superseded `NEXT_WAVE_SPEC_DRAFT.md` pointer, and the earlier `TERRA_HANDOFF_1_3.md`. Preserve all of them and include any not already committed in the Phase 34 PR. Do not delete/stash away another session's work or assume the working tree should be reset. Keep unrelated code out of the phase PR.

## Resume after the audit-method clarification (2026-11-01)

Phase 34 has begun on `claude/beginner-teaching` in `/private/tmp/terra-release-main`. Reuse that branch and its uncommitted SPEC/PROGRESS/planning/audit files; do not create another Phase 34 branch or replace these changes with stale original-workspace copies. `docs/BEGINNER_AUDIT.md` records partial evidence; it is not complete and no 1.4 release exists.

Read spec §7.1. A missing Simulator.app window is not a blocker when XCTest can interact with CoreSimulator and screenshots can be captured and visually inspected. Finish all §7 tasks with stepwise screenshot-reviewed navigation, without answer flags or an unlocked-path shortcut in the fresh beginner journey. Record checkpoints, inspected images, findings and limitations honestly. Existing passing tests alone do not meet the gate. Missing future 1.4 features are baseline findings, not reasons to require those features before implementation. Complete this baseline review, then continue Phase 34 and phases 35–38 through the already-authorized TestFlight release. Do not spend time reinstalling Xcode solely to obtain the GUI.

## What this release must achieve

1. Teach the goal, tile facts and prerequisites before scored questions; reopen already-taught notes in ordinary lessons without changing the current attempt.
2. Explain the actual hand shown, including shifted numbers, concrete suits, Dragons, Jokers and alternatives. Teach card-color relationships separately from physical tile artwork.
3. Make the first lesson and help controls understandable; disclose hint costs before consumption; clarify Helper modes/distance/dead reasons and wall games; scope tips to visible controls; compact the Charleston tracker.
4. Preserve own-card onboarding intent and provide a guided hand editor over the existing domain/notation model, with a safe advanced fallback and explicit card activation.
5. Verify the integrated beginner path, update release/listing material, merge every phase and ship 1.4 to TestFlight automatically.

Required copy, model contracts, regression scenarios and acceptance criteria are in the spec, especially §3 and §6. Do not simplify them into vague UX polish. Fix the reported defects without changing exercise seeds/IDs, grading, XP/stars, scoring rules, pass algorithms or persisted progress meaning. Assist Off still hides Helper. No celebration redesign in this wave.

## Ordered work: one PR per phase

| Phase | Suggested existing-style branch | Deliverable |
|---|---|---|
| 34 | `claude/beginner-teaching` | Fresh integrated-1.3 walkthrough, `docs/BEGINNER_AUDIT.md`, concept/prerequisite coverage, teaching/copy and ordinary-lesson notes. Add SPEC §20 reference/checklist and PROGRESS table. |
| 35 | `claude/concrete-feedback` | Deterministic concrete-target explanations and original pattern-color examples; core regression coverage. |
| 36 | `claude/beginner-flow` | First actions/help/hint disclosure, mode-aware tips, compact Charleston controls and scorekeeping context. |
| 37 | `claude/guided-card-entry` | Own-card setup routing/persistence, guided editor, semantic round trips, advanced source preservation and safe save/activation. |
| 38 | `claude/release-1-4` | Integrated QA, version/listing/release updates, then automatic export, validation, upload and processing confirmation. |

Recheck existing branches/PRs before creating duplicates. Start each phase from the preceding merged result. Tick its SPEC checklist and PROGRESS row and record behavioral fixes/deviations in DECISIONS in that same PR. Preserve previous waves' history. Attach created PRs to the Codex chat if the tool is available.

## Engineering and validation

Native Swift 6 + SwiftUI, iOS 17+. Foundation-only game/notation/domain logic stays in `Packages/MahjongCore`. The Xcode project comes from `project.yml` via XcodeGen; never commit generated project files. Reuse the existing engine/parser, settings decoder, CardEditing and import/share paths. No data resets, notation migration or second game engine.

Use the spec's §7 walkthrough without answer-revealing launch flags. An isolated simulator from the planning audit exists (`Mahjong Beginner Audit`, UUID `9DA1BF04-F904-4A96-8EB7-319538866252`); check availability/ownership before using it, or create your own. The old four targeted test passes and screenshots are historical baseline evidence, not a gate for your changes. A role-play audit is not an actual novice user study.

Each behavioral fix needs a regression test at the lowest suitable layer. Run targeted tests while iterating, drive changed UI and inspect screenshots in light/dark/AX5 and relevant small-phone/iPad compatibility layouts. Before pushing/merging each implementation phase run the full `tools/test.sh` on the final branch. It includes `swift test --package-path Packages/MahjongCore`, generation and app unit/UI tests; report actual counts and any retries. Test target names are `MahjongManiaTests` and `MahjongManiaUITests`; use generated-project destinations rather than stale examples. Inspect build logs and xcresult: zero compiler/analyzer warnings and no unresolved runtime layout warnings. Do not remove assertions, skip failures, add blind sleeps, or call a warning-free build proof that the UI is correct.

Record exact commands, outcomes, warning counts and screenshot artifact locations in each PR. Full UI gates may take much longer than the old estimate; let an active run finish and provide concise progress updates. Do not run competing suites on one simulator. Docs-only planning records require no app test run.

## Release and stopping condition

Follow spec §6.2 and current `RELEASING.md`. In Phase 38 set marketing version `1.4` through `project.yml`; the uploader controls monotonically increasing build numbers. Update TestFlight/WhatToTest, release history, listing/review notes and any affected screenshots; no scanning claims.

After the final QA PR merges, release from clean up-to-date main containing all phase PRs. Use the credential-loaded `zsh -ic` shell, dry-export and preserve the IPA with the actual documented uploader interface, validate that IPA with altool, then run the real `tools/upload_testflight.sh`. Keep all existing gates and build-bump behavior. Never echo/read credential files or print signing values, environment, keys or JWTs. If a build-bump PR is produced, merge it as documented. Check the exact app/version/build until processing is `VALID`; an accepted upload is not completion. Record actual evidence in the allowed release records. Never submit for App Store review.

Stop this task after 1.4 has processed successfully. **Do not start phases 39–42**, add camera permission, a scanning button, an API/backend, subscriptions, credits or ads. Owner pictures are not needed for 1.4; the separately specified scanner experiment can follow in the next task. If blocked by missing access or a concrete product decision, describe the exact blocker and completed work; do not silently weaken acceptance criteria.

Final report: merged PR links, shipped version/build and processing status, concise local/visual evidence, any remaining owner device actions. The user wants completed execution, not another implementation prompt.
