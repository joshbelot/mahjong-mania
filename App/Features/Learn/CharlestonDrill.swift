import Foundation
import MahjongCore

/// Pure logic of the Charleston Pass drill: a seeded 13-tile deal, validation of the player's three
/// tiles, and a score against the engine's pass suggestion.
struct CharlestonDrill: Sendable, Equatable {
  struct Pick: Sendable, Hashable {
    let tile: Tile
    let reason: String
  }

  struct Outcome: Sendable, Equatable {
    /// The player's tiles, in the order selected.
    let chosen: [Pick]
    /// The engine's `suggestPasses` set.
    let engine: [Pick]
    /// How many of the player's tiles are at least as unhelpful as the engine's set allows (0...3).
    let score: Int
    let explanation: String
    var isPerfect: Bool { score == CharlestonDrill.passCount }
  }

  static let passCount = 3
  private static let tolerance = 1e-9

  let seed: UInt64
  /// The 13 dealt tiles in display order. Selections refer to positions in this array.
  let hand: [Tile]

  init(seed: UInt64) {
    self.seed = seed
    self.hand = Wall.deal(seed: seed).hand.sortedForDisplay()
  }

  /// Jokers may never be passed.
  static func canSelect(_ tile: Tile) -> Bool {
    tile != .joker
  }

  /// Full marks extend the streak; anything less resets it.
  static func updatedStreak(_ current: Int, score: Int) -> Int {
    score >= passCount ? current + 1 : 0
  }

  /// Scores `selection` (positions in `hand`). Nil unless it is exactly three distinct positions of
  /// passable tiles.
  ///
  /// Score = number of the player's tiles whose utility is at most the highest utility in the engine's set.
  /// That is the same as the third-lowest utility among all passable tiles, so equally good picks count.
  func evaluate(selection: [Int], analyzer: Analyzer) -> Outcome? {
    guard selection.count == Self.passCount, Set(selection).count == selection.count,
      selection.allSatisfy({ hand.indices.contains($0) && Self.canSelect(hand[$0]) })
    else { return nil }

    let view = PlayerView(rack: hand)
    let top = WeightedTopLines(results: analyzer.analyze(view))
    let advice = analyzer.suggestPasses(view, count: Self.passCount)
    let held = hand.counts

    // Every passable copy and its utility. Copy `n` of a tile counts the lines that need more than `n`.
    var allUtilities: [Double] = []
    for (tile, count) in held where Self.canSelect(tile) {
      for instance in 0..<count { allUtilities.append(top.utility(of: tile, instance: instance)) }
    }
    allUtilities.sort()
    guard let threshold = allUtilities.dropFirst(Self.passCount - 1).first ?? allUtilities.last else {
      return nil
    }

    // When several copies of one tile are passed, give the player the spare (lowest-utility) copies.
    var passed: [Tile: Int] = [:]
    var chosen: [Pick] = []
    var worst: (tile: Tile, instance: Int, utility: Double)?
    var score = 0
    for position in selection {
      let tile = hand[position]
      let taken = passed[tile, default: 0]
      passed[tile] = taken + 1
      let instance = max(0, (held[tile] ?? 1) - 1 - taken)
      let utility = top.utility(of: tile, instance: instance)
      if utility <= threshold + Self.tolerance { score += 1 }
      if worst == nil || utility > (worst?.utility ?? 0) { worst = (tile, instance, utility) }
      chosen.append(Pick(tile: tile, reason: reason(tile, instance: instance, top: top, analyzer: analyzer)))
    }

    let engine = advice.passes.map { Pick(tile: $0.tile, reason: $0.reason) }
    let text = Self.explanation(
      score: score, worst: worst, threshold: threshold, engine: engine, focus: advice.focusSections,
      top: top)
    return Outcome(chosen: chosen, engine: engine, score: score, explanation: text)
  }

  /// The engine's reason templates, applied to any tile of the hand.
  private func reason(_ tile: Tile, instance: Int, top: WeightedTopLines, analyzer: Analyzer) -> String {
    let utility = top.utility(of: tile, instance: instance)
    if utility == 0 {
      return analyzer.coverage(of: tile) == 0 ? "No hand on this card uses it" : "Not used by your top hands"
    }
    if let line = top.strongestLine(using: tile, instance: instance) {
      return "Only helps \(line.line.displayName) (\(line.distance) away)"
    }
    return "Not used by your top hands"
  }

  private static func explanation(
    score: Int, worst: (tile: Tile, instance: Int, utility: Double)?, threshold: Double,
    engine: [Pick], focus: [String], top: WeightedTopLines
  ) -> String {
    var text: String
    switch score {
    case 3:
      text = "Great pass. All three tiles are as unhelpful to your best hands as the engine's picks."
    case 2:
      text = "Close. Two of your three are as good as the engine's picks."
    case 1:
      text = "One of your three is as good as the engine's picks."
    default:
      text = "These tiles are all still useful to your best hands."
    }
    if score < 3, let worst, worst.utility > threshold + tolerance,
      let line = top.strongestLine(using: worst.tile, instance: worst.instance)
    {
      text += " Your \(worst.tile.name) still helps \(line.line.displayName), which is \(awayText(line.distance))."
    }
    if score < 3, !engine.isEmpty {
      text += " The engine would pass " + engine.map(\.tile.name).joined(separator: ", ") + "."
    }
    if !focus.isEmpty {
      text += " Keep options open: you're strongest in " + focus.joined(separator: " and ") + "."
    }
    return text
  }
}
