import Foundation

public enum Wall {
  /// All 152 tiles of an American set, plus `blanks` blank tiles (0 to 6) when the table plays with them.
  public static func full(blanks: Int = 0) -> [Tile] {
    var tiles: [Tile] = []
    for tile in Tile.allCases {
      tiles.append(contentsOf: Array(repeating: tile, count: tile.copies))
    }
    tiles.append(contentsOf: Array(repeating: Tile.blank, count: max(0, min(blanks, Tile.maxBlanks))))
    return tiles
  }

  /// Shuffles the full wall with `seed` and splits off `count` tiles as a hand.
  public static func deal(seed: UInt64, count: Int = 13, blanks: Int = 0) -> (hand: [Tile], rest: [Tile]) {
    let shuffled = SeededRandom.shuffled(full(blanks: blanks), seed: seed)
    let n = max(0, min(count, shuffled.count))
    return (Array(shuffled[..<n]), Array(shuffled[n...]))
  }
}
