# Progress

Source of truth for where the build is. Updated by the lead on `main`.

| Phase | Status | Branch / PR |
|---|---|---|
| 0 Foundation | CI green, awaiting merge | `claude/phase-0-foundation` (PR 3) |
| 1 Tiles | written, core tests green | `claude/phase-1-tiles` (PR 4) |
| 2 Notation | written | `claude/phase-2-notation` |
| 3 Engine | written | `claude/phase-3-engine` |
| 4 Suggestions & scout | written | `claude/phase-4-suggest` |
| 5 Scoring | written | `claude/phase-5-scoring` |
| 6–12 | not started | |

**Next step:** merge Phase 0 then 1, then open and green PRs for 2, 3, 4, 5 in order. Then Phase 6 (design system).

**Environment notes:** no Swift toolchain in the authoring sandbox (see DECISIONS.md); rely on CI for `swift test` (core job runs on every push) and the iOS build (ios job runs on PRs and main). UI screenshots are published by CI to the `ci-screenshots` branch (`pr-<number>/`); view them via `raw.githubusercontent.com`.
