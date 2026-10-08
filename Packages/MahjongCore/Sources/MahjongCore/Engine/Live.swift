import Foundation

extension Engine {
  /// Copies of each tile that could still be out there:
  /// `copies − rack − exposed − seen`, floored at 0. Every tile type has an entry.
  public static func liveCounts(_ view: PlayerView, seen: TileCounts) -> TileCounts {
    var used = view.rack.counts
    for exposure in view.exposures {
      for tile in exposure.tiles { used[tile, default: 0] += 1 }
    }
    for (tile, count) in seen { used[tile, default: 0] += count }
    var live: TileCounts = [:]
    for tile in Tile.allCases { live[tile] = max(0, tile.copies - (used[tile] ?? 0)) }
    return live
  }
}
