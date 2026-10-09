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
| 10 Helper | in progress (sub-agent) | `claude/phase-10-helper` |
| 11 Learn | merged (11a content PR 10, 11b screens PR 13) | |
| 12 Settings, polish, release | 12a release tooling (PR 12), 12b Settings (PR 15), 12c Settings UI tests (PR 17) merged; remaining: final QA pass, `docs/RELEASE_HANDOFF.md` | |

**Next:** merge Phase 10 (Helper); then tick remaining SPEC boxes, final QA pass and `docs/RELEASE_HANDOFF.md`.

**Environment notes:** no Swift toolchain in the authoring sandbox (see DECISIONS.md); rely on CI. The `core` job runs on every push; the `ios` job runs on PRs and `main` (~10 min; a simulator launch timeout flake can happen, the test step retries failing tests and a failed job can be re-run once). UI screenshots are published by CI to the `ci-screenshots` branch (`pr-<number>/`); view them via `raw.githubusercontent.com`.
