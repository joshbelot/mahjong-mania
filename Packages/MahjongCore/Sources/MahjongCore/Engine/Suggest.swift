import Foundation

/// A highly ranked line with the weight it gets when judging which tiles matter.
struct WeightedLine {
  var result: LineResult
  var weight: Double
}

extension Analyzer {
  private static let topLineCount = 6

  /// The best `K = 6` possible lines, weighted by `1 / 2^(distance − bestDistance)` (SPEC §10.5).
  func weightedTopLines(_ results: [LineResult], view: PlayerView) -> [WeightedLine] {
    let possible = results.filter { $0.best.possible }.prefix(Self.topLineCount)
    guard let minimum = possible.first?.best.distance else { return [] }
    return possible.map { result in
      var weight = 1.0 / pow(2.0, Double(result.best.distance - minimum))
      if result.line.concealed && !view.exposures.isEmpty { weight *= 0.5 }
      return WeightedLine(result: result, weight: weight)
    }
  }

  /// Utility of the `instance`-th (0-based) copy of `tile` in the rack: the summed weight of the top lines
  /// that use more than `instance` copies of it.
  func utility(of tile: Tile, instance: Int, in top: [WeightedLine]) -> Double {
    var total = 0.0
    for entry in top where (entry.result.best.usedRack[tile] ?? 0) > instance { total += entry.weight }
    return total
  }

  /// Highest-weight top line that uses the `instance`-th copy of `tile`.
  private func strongestLine(using tile: Tile, instance: Int, in top: [WeightedLine]) -> WeightedLine? {
    var best: WeightedLine?
    for entry in top where (entry.result.best.usedRack[tile] ?? 0) > instance {
      if let current = best, current.weight >= entry.weight { continue }
      best = entry
    }
    return best
  }

  // MARK: Charleston passes

  /// Which `count` tiles to pass in the Charleston. Jokers are never suggested.
  public func suggestPasses(_ view: PlayerView, count: Int = 3) -> PassAdvice {
    let results = analyze(view)
    let top = weightedTopLines(results, view: view)
    let rackCounts = view.rack.counts

    struct Candidate {
      var tile: Tile
      var instance: Int
      var utility: Double
      var coverage: Int
      var held: Int
    }
    var candidates: [Candidate] = []
    for (tile, held) in rackCounts where tile != .joker {
      for instance in 0..<held {
        candidates.append(
          Candidate(
            tile: tile, instance: instance, utility: utility(of: tile, instance: instance, in: top),
            coverage: coverage(of: tile), held: held))
      }
    }
    candidates.sort { a, b in
      if a.utility != b.utility { return a.utility < b.utility }
      if a.coverage != b.coverage { return a.coverage < b.coverage }
      let singleA = a.held == 1
      let singleB = b.held == 1
      if singleA != singleB { return singleA }
      if a.tile != b.tile { return a.tile < b.tile }
      return a.instance < b.instance
    }

    let passes = candidates.prefix(max(0, count)).map { candidate -> PassSuggestion in
      let reason: String
      if candidate.utility == 0 {
        reason = candidate.coverage == 0 ? "No hand on this card uses it" : "Not used by your top hands"
      } else if let line = strongestLine(using: candidate.tile, instance: candidate.instance, in: top) {
        reason = "Only helps \(line.result.line.displayName) (\(line.result.best.distance) away)"
      } else {
        reason = "Not used by your top hands"
      }
      return PassSuggestion(tile: candidate.tile, reason: reason)
    }

    return PassAdvice(passes: Array(passes), focus: focusSections(top))
  }

  /// The top 2–3 sections by summed weight (later ones must carry at least a quarter of the leader's weight).
  private func focusSections(_ top: [WeightedLine]) -> [FocusSection] {
    var weights: [String: Double] = [:]
    var lineNames: [String: [String]] = [:]
    var order: [String] = []
    for entry in top {
      let section = entry.result.line.section
      if weights[section] == nil { order.append(section) }
      weights[section, default: 0] += entry.weight
      lineNames[section, default: []].append(entry.result.line.displayName)
    }
    let ranked = order.sorted { a, b in
      let wa = weights[a] ?? 0
      let wb = weights[b] ?? 0
      return wa != wb ? wa > wb : (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
    }
    guard let leader = ranked.first.flatMap({ weights[$0] }) else { return [] }
    var focus: [FocusSection] = []
    for (index, section) in ranked.prefix(3).enumerated() {
      if index >= 2 && (weights[section] ?? 0) < leader * 0.25 { break }
      focus.append(FocusSection(section: section, lines: lineNames[section] ?? []))
    }
    return focus
  }

  // MARK: Discards

  /// The three best tiles to discard from a 14-tile hand.
  public func suggestDiscards(
    _ view: PlayerView, seen: TileCounts = [:], danger: [Tile: Double] = [:]
  ) -> [DiscardSuggestion] {
    let results = analyze(view, seen: seen)
    let top = weightedTopLines(results, view: view)
    let held = view.rack.counts

    struct Candidate {
      var tile: Tile
      var distance: Int
      var utility: Double
      var danger: Double
      var lineName: String
    }
    var candidates: [Candidate] = []
    for (tile, count) in held where tile != .joker {
      var reduced = view
      reduced.rack.removeOne(tile)
      let after = analyze(reduced, seen: seen)
      guard let best = after.first else { continue }
      candidates.append(
        Candidate(
          tile: tile, distance: best.best.distance,
          utility: utility(of: tile, instance: count - 1, in: top), danger: danger[tile] ?? 0,
          lineName: best.line.displayName))
    }
    candidates.sort { a, b in
      if a.distance != b.distance { return a.distance < b.distance }
      if a.utility != b.utility { return a.utility < b.utility }
      if a.danger != b.danger { return a.danger < b.danger }
      return a.tile < b.tile
    }
    return candidates.prefix(3).map { candidate in
      var reason = "Keeps you \(candidate.distance) away on \(candidate.lineName)"
      if candidate.danger >= 0.5 { reason += " · risky: an opponent may need it" }
      return DiscardSuggestion(tile: candidate.tile, resultingDistance: candidate.distance, reason: reason)
    }
  }

  // MARK: Calling

  /// Can I call `tile`, just discarded by someone else? Mahjong verdicts first, then exposures by how close
  /// they leave you. Empty means "let it go".
  public func checkCall(_ view: PlayerView, tile: Tile) -> [CallVerdict] {
    let results = analyze(view)
    let candidates = results.filter { $0.best.possible }.prefix(10)
    let baseContext = EvalContext(view: view, live: nil)
    var verdicts: [(verdict: CallVerdict, rank: Int, distance: Int)] = []

    for (position, result) in candidates.enumerated() {
      let line = result.line
      let target = result.best.target

      var withTile = view
      withTile.rack.append(tile)
      let completed = Engine.evaluation(
        of: target, concealed: line.concealed, context: EvalContext(view: withTile, live: nil))
      if completed.possible && completed.distance == 0 {
        verdicts.append((.mahjong(line), position, 0))
        continue
      }
      if line.concealed { continue }

      let naturalsInRack = baseContext.rack[tile.sortIndex]
      let jokersInRack = baseContext.rack[Tile.joker.sortIndex]
      var bestExpose: (size: Int, distance: Int)?
      for group in target.groups where group.jokerOK && group.tile == tile {
        let fromRack = min(naturalsInRack, group.count - 1)
        let jokersNeeded = group.count - 1 - fromRack
        guard jokersNeeded <= jokersInRack else { continue }
        var after = view
        for _ in 0..<fromRack { after.rack.removeOne(tile) }
        for _ in 0..<jokersNeeded { after.rack.removeOne(.joker) }
        after.exposures.append(
          Exposure(
            tiles: Array(repeating: tile, count: 1 + fromRack)
              + Array(repeating: .joker, count: jokersNeeded)))
        let evaluation = Engine.evaluation(
          of: target, concealed: false, context: EvalContext(view: after, live: nil))
        guard evaluation.possible, evaluation.distance < result.best.distance else { continue }
        if let current = bestExpose, current.distance <= evaluation.distance { continue }
        bestExpose = (group.count, evaluation.distance)
      }
      if let bestExpose {
        verdicts.append(
          (.expose(line, groupSize: bestExpose.size, newDistance: bestExpose.distance), position, bestExpose.distance))
      }
    }

    verdicts.sort { a, b in
      let aMahjong: Bool
      if case .mahjong = a.verdict { aMahjong = true } else { aMahjong = false }
      let bMahjong: Bool
      if case .mahjong = b.verdict { bMahjong = true } else { bMahjong = false }
      if aMahjong != bMahjong { return aMahjong }
      if a.distance != b.distance { return a.distance < b.distance }
      return a.rank < b.rank
    }
    return verdicts.map(\.verdict)
  }
}

extension Array where Element == Tile {
  /// Removes the first occurrence of `tile`, if any.
  mutating func removeOne(_ tile: Tile) {
    if let index = firstIndex(of: tile) { remove(at: index) }
  }
}
