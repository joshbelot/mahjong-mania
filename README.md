# Mahjong Mania

A table-side companion app for **American Mahjong** on iPhone: a fast scorekeeper for experienced players and an on-demand coach for new ones. It is built natively with Swift 6 and SwiftUI (iOS 17+) and ships through TestFlight.

The full product and engineering plan is in **[docs/SPEC.md](docs/SPEC.md)**. Build status is tracked in **[docs/PROGRESS.md](docs/PROGRESS.md)**, and spec deviations in **[docs/DECISIONS.md](docs/DECISIONS.md)**.

## Layout

- `Packages/MahjongCore`: all game logic (Foundation only, testable anywhere with `swift test`).
- `App/`: the SwiftUI app target. `AppTests/` and `AppUITests/` hold unit and UI tests.
- `project.yml`: the XcodeGen spec. The `.xcodeproj` is generated and git-ignored; never edit or commit it.

## Develop

```sh
brew install xcodegen          # once
tools/bootstrap.sh             # generates MahjongMania.xcodeproj
swift test --package-path Packages/MahjongCore   # logic tests (macOS or Linux)
tools/test.sh                  # package tests + app unit/UI tests on a simulator (macOS)
```

## Release

See **[RELEASING.md](RELEASING.md)** for the one-time setup and the one-command TestFlight upload.

Not affiliated with the National Mah Jongg League.
