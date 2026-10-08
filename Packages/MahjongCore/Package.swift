// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MahjongCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MahjongCore", targets: ["MahjongCore"])
  ],
  targets: [
    .target(name: "MahjongCore"),
    .testTarget(name: "MahjongCoreTests", dependencies: ["MahjongCore"]),
  ]
)
