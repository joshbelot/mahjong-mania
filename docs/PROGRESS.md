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
| 8 Cards | in progress (sub-agent) | `claude/phase-8-cards` |
| 9 Game Night | in progress (sub-agent) | `claude/phase-9-game` |
| 10 Helper | waiting for 8, 9 | |
| 11 Learn | merged (11a content PR 10, 11b screens PR 13) | |
| 12 Settings, polish, release | 12a release tooling merged (PR 12), 12b Settings merged (PR 15); remaining: accessibility/empty-state pass, handoff doc, QA | |

**Next:** merge Phases 8 and 9, then Phase 10 (Helper), then the Phase 12 polish pass and `docs/RELEASE_HANDOFF.md`.

**Environment notes:** no Swift toolchain in the authoring sandbox (see DECISIONS.md); rely on CI. The `core` job runs on every push; the `ios` job runs on PRs and `main` (~10 min; a simulator launch timeout flake can happen, the test step retries failing tests and a failed job can be re-run once). UI screenshots are published by CI to the `ci-screenshots` branch (`pr-<number>/`); view them via `raw.githubusercontent.com`.
