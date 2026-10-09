import Foundation
import MahjongCore

/// Seeds for the drills. Small numbers so the "Deal #123456" label stays readable.
enum DrillSeed {
  static func random() -> UInt64 {
    UInt64.random(in: 1...999_999)
  }

  /// A random seed, or the one given with the `-UITestDrillSeed <n>` launch argument (UI tests).
  static func initial() -> UInt64 {
    let forced = UserDefaults.standard.integer(forKey: "UITestDrillSeed")
    return forced > 0 ? UInt64(forced) : random()
  }
}

/// "3 tiles away" wording shared by the drills.
func awayText(_ distance: Int) -> String {
  distance == 1 ? "1 tile away" : "\(distance) tiles away"
}

/// The best lines of an analysis, weighted like the engine's pass suggestions (SPEC §10.5): the top six
/// possible lines, each with weight `1 / 2^(distance - bestDistance)`.
struct WeightedTopLines: Sendable {
  struct Entry: Sendable {
    let line: CardLine
    let distance: Int
    let usedRack: TileCounts
    let weight: Double
  }

  static let lineCount = 6
  let entries: [Entry]

  init(results: [LineResult]) {
    let possible = results.filter { $0.best.possible }.prefix(Self.lineCount)
    guard let minimum = possible.first?.best.distance else {
      entries = []
      return
    }
    entries = possible.map { result in
      Entry(
        line: result.line, distance: result.best.distance, usedRack: result.best.usedRack,
        weight: 1.0 / pow(2.0, Double(result.best.distance - minimum)))
    }
  }

  /// Summed weight of the top lines that use more than `instance` copies of `tile`.
  func utility(of tile: Tile, instance: Int) -> Double {
    var total = 0.0
    for entry in entries where (entry.usedRack[tile] ?? 0) > instance { total += entry.weight }
    return total
  }

  /// The highest-weight top line that uses the `instance`-th copy of `tile`.
  func strongestLine(using tile: Tile, instance: Int) -> Entry? {
    var best: Entry?
    for entry in entries where (entry.usedRack[tile] ?? 0) > instance {
      if let current = best, current.weight >= entry.weight { continue }
      best = entry
    }
    return best
  }
}
