import Foundation

/// The public pages the App Store listing points at (SPEC §19.6). They open in Safari.
enum AppLinks {
  static let site = URL(string: "https://joshbelot.github.io/mahjong-mania/")!
  static let privacy = URL(string: "https://joshbelot.github.io/mahjong-mania/privacy.html")!
  static let support = URL(string: "https://joshbelot.github.io/mahjong-mania/support.html")!
}
