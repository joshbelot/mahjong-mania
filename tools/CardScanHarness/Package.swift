// swift-tools-version: 6.0
import PackageDescription

// Local-only evaluation harness for the 1.5 card-scanning experiment (docs/CARD_SCAN_EVALUATION.md).
// macOS command-line tool. It is not part of the app, has no network code, and is not run by CI.
// Swift 5 language mode: this is throwaway-grade tooling that drives CoreGraphics/Vision synchronously.
let package = Package(
  name: "CardScanHarness",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "cardscan", targets: ["cardscan"])],
  dependencies: [.package(path: "../../Packages/MahjongCore")],
  targets: [
    .target(
      name: "CardScanKit",
      dependencies: [.product(name: "MahjongCore", package: "MahjongCore")],
      swiftSettings: [.swiftLanguageMode(.v5)]),
    .executableTarget(
      name: "cardscan", dependencies: ["CardScanKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(
      name: "CardScanKitTests", dependencies: ["CardScanKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]),
  ]
)
