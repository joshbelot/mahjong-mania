import Foundation

/// The best lines of an analysis, weighted like the engine's pass suggestions (SPEC §10.5): the top six
/// possible lines, each with weight `1 / 2^(distance - bestDistance)`. Same scoring as the v1 drills.
struct PassTop: Sendable {
  struct Entry: Sendable {
    let line: CardLine
    let distance: Int
    let usedRack: TileCounts
    let weight: Double
  }

  static let lineCount = 6
  static let tolerance = 1e-9
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

  func utility(of tile: Tile, instance: Int) -> Double {
    var total = 0.0
    for entry in entries where (entry.usedRack[tile] ?? 0) > instance { total += entry.weight }
    return total
  }

  func strongestLine(using tile: Tile, instance: Int) -> Entry? {
    var best: Entry?
    for entry in entries where (entry.usedRack[tile] ?? 0) > instance {
      if let current = best, current.weight >= entry.weight { continue }
      best = entry
    }
    return best
  }

  /// Utility of every passable copy in `hand`, lowest first.
  func passableUtilities(hand: [Tile]) -> [Double] {
    var utilities: [Double] = []
    let held = hand.counts
    for tile in Tile.allCases where tile != .joker && (held[tile] ?? 0) > 0 {
      for instance in 0..<(held[tile] ?? 0) { utilities.append(utility(of: tile, instance: instance)) }
    }
    return utilities.sorted()
  }

  /// The third-lowest utility: a pass tile is "as good as the engine's" when it is at most this.
  func threshold(hand: [Tile], count: Int = 3) -> Double? {
    let utilities = passableUtilities(hand: hand)
    return utilities.dropFirst(count - 1).first ?? utilities.last
  }
}

struct PassOutcome {
  var score: Int
  var explanation: String
  var enginePasses: [Tile]
}

enum PassScorer {
  /// Scores `selection` (positions in `hand`) like the v1 Charleston drill: the number of the player's
  /// tiles that are at most as useful as the third-least useful tile in the hand. Nil unless the selection
  /// is exactly three distinct, passable positions.
  static func score(hand: [Tile], selection: [Int], analyzer: Analyzer) -> PassOutcome? {
    let passCount = 3
    guard selection.count == passCount, Set(selection).count == selection.count,
      selection.allSatisfy({ hand.indices.contains($0) && hand[$0] != .joker })
    else { return nil }

    let view = PlayerView(rack: hand)
    let top = PassTop(results: analyzer.analyze(view))
    let advice = analyzer.suggestPasses(view, count: passCount)
    let held = hand.counts
    guard let threshold = top.threshold(hand: hand) else { return nil }

    var passed: [Tile: Int] = [:]
    var worst: (tile: Tile, instance: Int, utility: Double)?
    var score = 0
    for position in selection {
      let tile = hand[position]
      let taken = passed[tile, default: 0]
      passed[tile] = taken + 1
      let instance = max(0, (held[tile] ?? 1) - 1 - taken)
      let utility = top.utility(of: tile, instance: instance)
      if utility <= threshold + PassTop.tolerance { score += 1 }
      if worst == nil || utility > (worst?.utility ?? 0) { worst = (tile, instance, utility) }
    }

    var text: String
    switch score {
    case 3: text = "Great pass. All three tiles are as unhelpful to your best hands as they can be."
    case 2: text = "Close. Two of your three are as unhelpful as they can be."
    case 1: text = "One of your three is as unhelpful as it can be."
    default: text = "These tiles are all still useful to your best hands."
    }
    if score < 3, let worst, worst.utility > threshold + PassTop.tolerance,
      let line = top.strongestLine(using: worst.tile, instance: worst.instance)
    {
      text += " Your \(worst.tile.name) still helps \(line.line.displayName), which is \(awayText(line.distance))."
    }
    let engine = advice.passes.map(\.tile)
    if score < 3, !engine.isEmpty {
      text += " Better to pass " + engine.map(\.name).joined(separator: ", ") + "."
    }
    if !advice.focusSections.isEmpty {
      text += " Keep options open: you're strongest in " + advice.focusSections.joined(separator: " and ") + "."
    }
    return PassOutcome(score: score, explanation: text, enginePasses: engine)
  }
}

enum PickScorer {
  struct Ranked {
    var line: CardLine
    var distance: Int
    var possible: Bool
  }

  /// The v1 Pick-a-Hand rule: right when among the three closest possible lines or as close as the third.
  /// With `offered` set, only those lines compete and the pick must be as close as the closest of them.
  static func grade(
    hand: [Tile], picked: CardLine, offered: [CardLine]?, analyzer: Analyzer
  ) -> (correct: Bool, best: [Ranked], explanation: String)? {
    let results = analyzer.analyze(PlayerView(rack: hand))
    func ranked(_ result: LineResult) -> Ranked {
      Ranked(line: result.line, distance: result.best.distance, possible: result.best.possible)
    }
    guard let pickedResult = results.first(where: { $0.line.id == picked.id }) else { return nil }
    let pickedRanked = ranked(pickedResult)
    var pool = results
    if let offered {
      let ids = Set(offered.map(\.id))
      pool = results.filter { ids.contains($0.line.id) }
    }
    let possible = pool.filter { $0.best.possible }.map(ranked)
    let top = Array(possible.prefix(3))
    var correct: Bool
    if offered != nil {
      correct = pickedRanked.possible && pickedRanked.distance == possible.first?.distance
    } else {
      correct = top.contains { $0.line.id == pickedRanked.line.id }
      if !correct, pickedRanked.possible, top.count == 3, let third = top.last {
        correct = pickedRanked.distance <= third.distance
      }
    }
    let bestResult = pool.first { $0.best.possible }
    return (
      correct, offered == nil ? top : Array(possible.filter { $0.distance == possible.first?.distance }),
      explanation(best: bestResult, picked: pickedRanked, isCorrect: correct)
    )
  }

  private static func explanation(best: LineResult?, picked: Ranked, isCorrect: Bool) -> String {
    guard let best else { return "None of the lines can be made from these tiles." }
    let held = best.best.usedRack.values.reduce(0, +)
    var text =
      "Your closest line is \(best.line.displayName) in \(best.line.section), \(awayText(best.best.distance)): \(held) of your 13 tiles already fit it."
    if best.best.distance <= 6 && !best.best.missing.isEmpty {
      text += " You still need " + missingText(best.best.missing, limit: 3) + "."
    }
    guard picked.possible else { return text + " \(picked.line.displayName) cannot be made from this hand." }
    if picked.line.id == best.line.id {
      text += " You picked it, so you are aiming exactly where the tiles point."
    } else if isCorrect {
      text += " \(picked.line.displayName) is \(awayText(picked.distance)), about as close, so it is a good pick too."
    } else {
      let gap = max(0, picked.distance - best.best.distance)
      text +=
        " \(picked.line.displayName) is \(awayText(picked.distance)), \(gap) further away. Look for lines that use more of the tiles you already hold."
    }
    return text
  }
}
