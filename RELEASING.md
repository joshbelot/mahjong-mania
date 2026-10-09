# Releasing Mahjong Mania to TestFlight

One command ships a build, with no Xcode signing UI. You do the one-time setup below once; after that, every release is the same command.

## One-time setup (only you can do this)

- [ ] **Apple Developer Program** membership (paid). You already have this.
- [ ] **Team ID**: developer.apple.com → Membership → Team ID (10 characters).
- [ ] **Bundle ID**: developer.apple.com → Identifiers → "+" → App IDs → register the explicit ID `com.joshbelot.mahjongmania`. No capabilities need to be ticked: the app uses no HealthKit, App Groups, Push or Background Modes.
- [ ] **App record**: App Store Connect → Apps → "+" → New App → platform iOS, name "Mahjong Mania" (or your final name; it must be unique on the App Store), primary language English (US), the bundle ID above, SKU `mahjongmania`. **This must exist before the first upload**, or the upload fails with an unhelpful error.
- [ ] **App Store Connect API key**: Users and Access → Integrations → App Store Connect API → generate a key with the **App Manager** role. Download the `.p8` **once** to `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8` (outside this repo). Note the Key ID and the Issuer ID.
- [ ] **Shell variables**: add this to `~/.zshrc` (the values never go in the repo):
  ```sh
  export DEVELOPMENT_TEAM=XXXXXXXXXX
  export ASC_KEY_ID=XXXXXXXXXX
  export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
  ```
- [ ] **Tools**: Xcode 26 or newer (with the command-line tools selected: `xcode-select -p`) and XcodeGen (`brew install xcodegen`).
- [ ] **Privacy and test info** (App Store Connect → the app):
  - App Privacy → answer **"Data Not Collected"**.
  - TestFlight → Test Information → paste the beta description from `TestFlight/BetaDescription.txt`, add a feedback email, and paste "What to Test" from `TestFlight/WhatToTest.txt`. No sign-in is required (the app has no login).
- [ ] **Testers**: create an **internal testing group** and add team members (up to 100, no review). For friends outside your team create an **external group** (up to 10,000 testers by email or public link). The first build of each version goes through Beta App Review (usually under a day).

## How to ship a build

From a clean, up-to-date `main` checkout, in a terminal:

```sh
zsh -ic 'tools/upload_testflight.sh --dry-run'   # first time: archives and exports, uploads nothing
zsh -ic 'tools/upload_testflight.sh'             # the real upload
```

`zsh -ic` makes sure `~/.zshrc` is loaded so the variables above exist. The script:

1. checks the variables, the key file, the tools (Xcode 26+) and that you are on `main`, clean, and up to date with `origin/main`;
2. builds in a temporary worktree of `origin/main`, so local edits can't sneak into a release;
3. runs all tests (`tools/test.sh`) and stops on any failure;
4. increases the build number (`tools/bump_build.sh`), archives, exports and uploads;
5. commits the bump to `main` (`Bump build to N [skip ci]`). If `main` is protected it pushes `release/build-N` instead; open and merge a PR from it before the next release.

A dry run does steps 1–3 and the archive/export, leaves the build number unchanged and pushes nothing. Never run the script with `set -x`, `env` or `printenv` around it: those would print your credentials.

## A new version (not just a new build)

Edit `MARKETING_VERSION` in `project.yml` through a PR (for example `1.0` → `1.1`). The build number (`CURRENT_PROJECT_VERSION`) keeps increasing and is never reset.

## After the upload

- Processing takes 5–30 minutes. You get an email, and the build then appears under TestFlight.
- Internal testers can install immediately. External testers need Beta App Review for the first build of each version.
- Builds expire after 90 days.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| "Missing DEVELOPMENT_TEAM / ASC_*" | Run via `zsh -ic` so `~/.zshrc` is loaded |
| Upload fails with a vague "no suitable application records" / authentication-style error | The App Store Connect app record doesn't exist yet, or the bundle ID differs |
| "The bundle version must be higher than the previously uploaded version" | The build number wasn't bumped, or the bump wasn't pushed. Run `tools/bump_build.sh`, commit, retry |
| Processing email says "Missing Info.plist value" / "ITMS-90683" | A permission key is missing for an API in use. Add the `NS…UsageDescription` to `project.yml` |
| "ITMS-91053: Missing API declaration" | Add the required-reason API to `App/Resources/PrivacyInfo.xcprivacy` |
| Icon rejected (alpha) | Re-export the icon as RGB without alpha (`python3 tools/make_icon.py <path>`) |
| Signing errors about certificates | Ensure the API key has the App Manager role and `-allowProvisioningUpdates` is present |

## Rules for agents and contributors

- Never commit or print secrets (`.p8` contents, key IDs, issuer IDs, team ID values in logs).
- Never hand-edit `*.xcodeproj` or the generated `Info.plist`; change `project.yml` and run `xcodegen generate`.
- Never reuse a build number. Always commit and push the bump.
- Never upload from a dirty tree or a non-`main` checkout. The script enforces this.
- Sideloading tools (AltStore/SideStore, free-account provisioning) are not needed and must not be added.
