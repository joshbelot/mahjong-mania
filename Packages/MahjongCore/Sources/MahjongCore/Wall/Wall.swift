import Foundation

public enum Wall {
  /// All 152 tiles of an American set.
  public static func full() -> [Tile] {
    var tiles: [Tile] = []
    for tile in Tile.allCases {
      tiles.append(contentsOf: Array(repeating: tile, count: tile.copies))
    }
    return tiles
  }

  /// Shuffles the full wall with `seed` and splits off `count` tiles as a hand.
  public static func deal(seed: UInt64, count: Int = 13) -> (hand: [Tile], rest: [Tile]) {
    let shuffled = SeededRandom.shuffled(full(), seed: seed)
    let n = max(0, min(count, shuffled.count))
    return (Array(shuffled[..<n]), Array(shuffled[n...]))
  }
}
