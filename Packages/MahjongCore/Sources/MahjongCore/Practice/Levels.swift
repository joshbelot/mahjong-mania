import Foundation

/// Player levels and titles (SPEC §18.6).
public enum Levels {
  /// XP to go from `level` to `level + 1`.
  public static func xpToNext(_ level: Int) -> Int { 100 + 25 * (max(1, level) - 1) }

  public struct Position: Equatable, Sendable {
    public var level: Int
    /// XP earned inside the current level.
    public var into: Int
    /// XP the current level needs in all.
    public var needed: Int
    public var title: String
  }

  public static func position(totalXP: Int) -> Position {
    var level = 1
    var remaining = max(0, totalXP)
    while remaining >= xpToNext(level) {
      remaining -= xpToNext(level)
      level += 1
    }
    return Position(level: level, into: remaining, needed: xpToNext(level), title: title(level: level))
  }

  /// Total XP at which `level` starts.
  public static func xpAtStart(of level: Int) -> Int {
    guard level > 1 else { return 0 }
    return (1..<level).reduce(0) { $0 + xpToNext($1) }
  }

  static let titles: [(level: Int, title: String)] = [
    (1, "Newcomer"), (3, "Tile Spotter"), (6, "Card Reader"), (10, "Charleston Cadet"),
    (15, "Joker Wrangler"), (20, "Pattern Pro"), (30, "Card Shark"), (40, "Mahj Maven"),
    (50, "Mahjong Master"),
  ]

  public static func title(level: Int) -> String {
    titles.last { $0.level <= level }?.title ?? "Newcomer"
  }
}
