# Release handoff — Mahjong Mania v1.2

_Status: all 1.2 phases (21–27) are merged and the 1.2 upload was made by the agent from a clean `main` with the owner's authorisation (SPEC §18.11). The build number and processing state are in `docs/PROGRESS.md`._

## 1.2 in short

Plan: `docs/SPEC.md` §18. Decisions: `docs/DECISIONS.md` (entries dated 2026-10-17 and 2026-10-18). Open questions for the owner: `docs/PROGRESS.md`.

Practice became a game:

- **Exercise engine** (21, `MahjongCore/Practice`): 13 question types × 3 difficulties, generated from `(type, seed, difficulty, focus)` on the built-in Practice Card, graded in core with explanations and hints; deal filters keep early deals clear-cut.
- **Progress logic** (22): the curriculum (10 units, lessons, review nodes, checkpoints, gold), XP, levels, streaks and freezes over `LocalDay` (whole-day arithmetic, safe across DST and time zones), badges, the spaced review queue, the Daily Deal and `PracticeProgress`, the one value type the app saves to `practice.json`.
- **Practice tab** (23): header strip, path, lesson player, test-out, placement during onboarding; the two 1.1 drills moved here.
- **Feel** (24): animations, haptics, eight generated sounds (`tools/make_sounds.py`), confetti celebrations, Reduce Motion variants; Settings → Sound effects.
- **Streaks and profile** (25): daily goal, streak flame and freezes, milestones, kind restart messages, profile with calendar, accuracy and badges.
- **Daily Deal, Speed Round, free play** (26): see the Practice tab; Settings → Practice has the goal, "No timer in Speed Round" and "Reset practice progress".

## Things only a person with an iPhone can check

- Haptics (right/wrong/level-up), the sounds through the speaker and the silent switch (the audio session is `.ambient`), real-device speed of a lesson, VoiceOver by hand through a lesson and the path, and installing the TestFlight build.
- Whether a day change at real midnight (and a time-zone change while travelling) behaves: the logic is tested on whole days, but only a phone can prove the system clock events.
- Sharing the Daily Deal text into Messages (the share sheet is the system's).

## Known limitations

- The Daily Deal has no shared leaderboard (no backend, by design).
- A streak can't be repaired after the fact; freezes are earned every 7 days up to two.
- Free play on your own card never feeds the review queue (a review rebuilds questions on the Practice Card).
- The 1.1 limitations below still apply. Everything under "Your one-time setup" is unchanged.

---

# Earlier handoff: Mahjong Mania v1.1

_Status: all 1.1 phases (13–19) are merged and the 1.1 upload was made by the agent from a clean `main` with the owner's authorisation (SPEC §17.8). The build number and processing state are in `docs/PROGRESS.md`._

## 1.1 in short

Plan: `docs/SPEC.md` §17. Decisions: `docs/DECISIONS.md` (entries dated 2026-10-16). Open questions for the owner: `docs/PROGRESS.md`.

- **Plain words** (13): "Hide tiles"/"Show tiles"; "Your exposed sets" with an explainer sheet; Scout and "Tiles already played" wording; Glossary and a Coach tip.
- **Charleston** (14): East switch (14 tiles), pass tracker ("Pass 1 of 7 · Right"), a locked 3-tile suggestion with "✓ Passed", "Suggest again", "Stop after this Charleston", "Start over".
- **Rule book** (15, 16): `RuleSet` holds `rules: [HouseRule]` (19 built-ins plus custom notes and scoring rules); 1.0 files migrate with identical totals; Settings → House rules with a detail screen and live example per rule; Learn → House rules explained; the Charleston tracker follows the book.
- **Blanks** (17): optional blank tiles (rule `table.blanks`), a Blank key, never suggested, swap advice, a dead-line exception.
- **Tile styles** (18): Classic, Traditional, Large print, Modern.
- **QR cards** (19): `mahjongmania://card?v=1&d=…` links (raw DEFLATE + base64url), a QR sheet and PNG share, import from a link or a picture. URL scheme registered in `project.yml`.

## Things only a person with an iPhone can check

- Scan a card's QR code with the system Camera on a real device and confirm iOS offers to open Mahjong Mania. (The simulator tests open the same link directly, and the codec is tested by rendering and detecting its own image.)
- Haptics, real-device speed, VoiceOver by hand on the new screens, and installing the TestFlight build.

## Known limitations

- A card whose text is too long for a QR code (over 2,000 characters as a link, after dropping its comments) is offered as a file instead.
- The blanks rule's "may be passed in the Charleston" option is stored but changes nothing: the Helper never suggests passing a blank.
- Everything under "Known limitations" and "Your one-time setup" below still applies.

---

# Earlier handoff: Mahjong Mania v1.0 (first TestFlight build)

_Status: all phases 0–12 are merged. The final CI run on `main` after the last merge was still in progress when this was written; check that it is green before releasing._

## What was built

A native iPhone app (Swift 6, SwiftUI, iOS 17+, portrait only) with these parts. The full plan is `docs/SPEC.md`; progress and decisions are in `docs/PROGRESS.md` and `docs/DECISIONS.md`.

- **Game Night**: players roster, sessions (3 or 4 players), hand recording with NMJL-style payouts (discard, self-pick, jokerless, wall game, adjustments), dealer rotation, edit/undo, house-rule editor, money settle-up, summary and share, history, player stats, keep-awake.
- **Hand Helper**: tile keyboard, closest-hands ranking with distance, missing tiles, dead-tile detection and "jokerless possible", Charleston pass suggestions, discard suggestions, "Can I call it?", Scout mode for opponents' exposures, Assist level (Off / Peek / Coach) gating.
- **Cards**: the original Practice Card (37 hands, built into the app), your own cards via a compact notation with a live preview, bulk paste import, share/export, "Practise this hand".
- **Learn**: rules quick reference, tile guide, reading a card, notation guide, glossary, and the Pick-a-Hand and Charleston Pass drills with best streaks; onboarding and Coach tips.
- **Settings**: assist level, theme, haptics, keep awake, default rules, money, tile sort, About, Reset all data.
- **Engineering**: all game logic is in the Foundation-only Swift package `Packages/MahjongCore` (Swift Testing, run on Linux and macOS in CI); the app target has unit tests and XCUITest flows with screenshots; no third-party dependencies; no permissions or entitlements; privacy manifest; final 1024 px icon (RGB, no alpha); one-command TestFlight pipeline.

## Known limitations

- **Never run on a device or by a human.** The authoring sandbox had no Swift toolchain or Xcode; everything was compiled and tested only by GitHub Actions (Linux `swift test` for MahjongCore; macOS simulator build, unit tests, UI tests and an unsigned Release archive for the app). Screenshots were reviewed from CI.
- **The signed archive and the TestFlight upload have never been run.** `tools/upload_testflight.sh` was syntax-checked and its failure paths exercised, but archive/export/upload need your Mac, Xcode 26 and your credentials. Run `--dry-run` first.
- Phase 0 acceptance "signed archive with `DEVELOPMENT_TEAM`" and Phase 12 "owner runs a real upload" are owner steps (SPEC ticks left open).
- MahjongCore line coverage was printed by CI but not checked against the 95% target; the Phase 10 Instruments timing check could not be done (the `core` job's 200-analysis timing test is the only performance evidence).
- Cards: editing a hand in a user card rewrites its text, dropping comments and invalid lines; the notation key row appends at the end of the text.
- iPhone only, portrait only, no iPad layout, no 5-player tables. Helper results are not run off the main actor.
- The full `ios` CI job takes 25–50 minutes because of the UI-test suite.
- Spec deviations are listed in `docs/DECISIONS.md`.

## Your one-time setup (only you can do these)

See `RELEASING.md` for the full checklist with explanations. In short:

1. Team ID from developer.apple.com → Membership.
2. Register the explicit App ID `com.joshbelot.mahjongmania` (no capabilities).
3. App Store Connect → Apps → "+" → New App (iOS, name "Mahjong Mania", English (US), the bundle ID above, SKU `mahjongmania`). **This must exist before the first upload.**
4. App Store Connect → Users and Access → Integrations → App Store Connect API → create a key with the **App Manager** role; download the `.p8` once to `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8`; note the Key ID and Issuer ID.
5. Add to `~/.zshrc`:
   ```sh
   export DEVELOPMENT_TEAM=XXXXXXXXXX
   export ASC_KEY_ID=XXXXXXXXXX
   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
   ```
6. Install Xcode 26 or newer and XcodeGen (`brew install xcodegen`).
7. App Store Connect → the app → App Privacy: "Data Not Collected". TestFlight → Test Information: paste `TestFlight/BetaDescription.txt` and `TestFlight/WhatToTest.txt`, add a feedback email.
8. Create an internal testing group (team members, no review) and, for friends, an external group (first build of each version goes through Beta App Review).

## The commands to run on your Mac

From a clean checkout of `main` (pull first):

```sh
zsh -ic 'tools/upload_testflight.sh --dry-run'
```

That runs the tests, archives and exports without uploading and leaves the build number unchanged. If it ends with "Dry run complete", ship it:

```sh
zsh -ic 'tools/upload_testflight.sh'
```

Processing takes 5–30 minutes; you get an email and the build appears under TestFlight.

## Device-only checks still to do

Covered by UI tests on the simulator: onboarding, Game Night 6-hand script with totals/settle-up/persistence across relaunch, Cards import/duplicate/edit, Learn tour and drills (incl. large text), Helper assist gating, Settings and reset. Still to do by hand on a physical iPhone (manual QA checklist, SPEC §13):

- [ ] First launch → onboarding → Game tab; play a real 8-hand game night (self-pick jokerless, discard, wall game, adjustment, edit, undo), end it, check settle-up and the share text.
- [ ] Helper: Charleston never suggests jokers; Playing discard + call check; Scout with 2 opponents; speed of results per tile tap.
- [ ] Cards: duplicate, edit, import, export; the active card is used in Record hand and the Helper.
- [ ] Dark mode everywhere; largest accessibility text size; VoiceOver on tiles and the rack.
- [ ] Force-quit mid-session → reopen → session intact. Airplane mode.
- [ ] Haptics feel right and the screen stays awake on the scoreboard.
- [ ] Signed archive, `--dry-run`, then the real upload; install the TestFlight build.
