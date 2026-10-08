import Foundation

public typealias TileCounts = [Tile: Int]

extension Array where Element == Tile {
  /// Number of each tile in the array.
  public var counts: TileCounts {
    var result: TileCounts = [:]
    for tile in self { result[tile, default: 0] += 1 }
    return result
  }

  /// The tiles in `Tile.allCases` order.
  public func sortedForDisplay() -> [Tile] {
    sorted()
  }
}
