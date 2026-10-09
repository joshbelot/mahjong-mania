# Release handoff — Mahjong Mania v1.0 (first TestFlight build)

_Status: DRAFT. The lead fills in the final sections when every phase is merged and CI is green on `main`._

## What was built

A native iPhone app (Swift 6, SwiftUI, iOS 17+, portrait only) with these parts. The full plan is `docs/SPEC.md`; progress and decisions are in `docs/PROGRESS.md` and `docs/DECISIONS.md`.

- **Game Night**: players roster, sessions (3 or 4 players), hand recording with NMJL-style payouts (discard, self-pick, jokerless, wall game, adjustments), dealer rotation, edit/undo, house-rule editor, money settle-up, summary and share, history, player stats, keep-awake.
- **Hand Helper**: tile keyboard, closest-hands ranking with distance, missing tiles, dead-tile detection and "jokerless possible", Charleston pass suggestions, discard suggestions, "Can I call it?", Scout mode for opponents' exposures, Assist level (Off / Peek / Coach) gating.
- **Cards**: the original Practice Card (37 hands, built into the app), your own cards via a compact notation with a live preview, bulk paste import, share/export, "Practise this hand".
- **Learn**: rules quick reference, tile guide, reading a card, notation guide, glossary, and the Pick-a-Hand and Charleston Pass drills with best streaks; onboarding and Coach tips.
- **Settings**: assist level, theme, haptics, keep awake, default rules, money, tile sort, About, Reset all data.
- **Engineering**: all game logic is in the Foundation-only Swift package `Packages/MahjongCore` (Swift Testing, run on Linux and macOS in CI); the app target has unit tests and XCUITest flows with screenshots; no third-party dependencies; no permissions or entitlements; privacy manifest; final 1024 px icon (RGB, no alpha); one-command TestFlight pipeline.

## Known limitations

_(filled in at the end)_

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

_(filled in at the end)_
