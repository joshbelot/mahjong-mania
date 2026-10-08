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
| 6 Design system | in progress (sub-agent) | `claude/phase-6-design-system` |
| 7 Stores | merged | PR 9 |
| 8 Cards | waiting for 6 | |
| 9 Game Night | waiting for 6 | |
| 10 Helper | waiting for 6, 8 | |
| 11 Learn | 11a content in review (PR 10); 11b screens waiting for 6 | `claude/phase-11a-content` |
| 12 Settings, polish, release | release tooling written on `claude/phase-12a-release` (upload script, RELEASING.md, TestFlight drafts, final icon); Settings/polish waiting for 6, 9 | |

**Next:** merge Phase 6 and 11a, then launch Phases 8, 9, 11b in parallel (assignments are in the lead's notes), then 10, then 12.

**Environment notes:** no Swift toolchain in the authoring sandbox (see DECISIONS.md); rely on CI. The `core` job runs on every push; the `ios` job runs on PRs and `main` (~10 min; a simulator launch timeout flake can happen, the test step retries failing tests and a failed job can be re-run once). UI screenshots are published by CI to the `ci-screenshots` branch (`pr-<number>/`); view them via `raw.githubusercontent.com`.
