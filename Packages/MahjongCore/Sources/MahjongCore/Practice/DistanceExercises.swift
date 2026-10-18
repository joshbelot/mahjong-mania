import Foundation

/// `howFar` and `neededTile` (SPEC §18.3): measuring how close a hand is.
enum DistanceExercises {
  /// 13 tiles that hold `14 - distance` tiles of a random hand of `lineIndex`, topped up with random tiles.
  static func nearHand(
    _ analyzer: Analyzer, lineIndex: Int, distance: Int, jokers: Int, rng: inout SeededRandom
  ) -> [Tile]? {
    guard let target = analyzer.randomTarget(at: lineIndex, rng: &rng) else { return nil }
    let all = rng.shuffled(Exercises.groupTiles(of: target, jokers: jokers, rng: &rng).flatMap { $0 })
    let kept = Array(all.prefix(14 - distance))
    let hand = kept + Exercises.noiseTiles(13 - kept.count, besides: kept, jokers: false, rng: &rng)
    return hand.sortedForDisplay()
  }

  static func howFar(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    guard let lineIndex = rng.element(of: analyzer.usableLineIndexes) else {
      return Built(exercise: Exercise(id: id, prompt: "How many tiles away is this hand?", key: .none), ok: false)
    }
    let line = analyzer.card.lines[lineIndex]
    let range: ClosedRange<Int>
    switch id.difficulty {
    case 1: range = 1...3
    case 2: range = 2...5
    default: range = 3...6
    }
    let planned = rng.int(in: range)
    let jokers = id.difficulty >= 3 ? rng.int(in: 1...2) : 0
    guard let hand = nearHand(analyzer, lineIndex: lineIndex, distance: planned, jokers: jokers, rng: &rng),
      let evaluation = analyzer.evaluation(at: lineIndex, tiles: hand)
    else {
      return Built(exercise: Exercise(id: id, prompt: "How many tiles away is this hand?", key: .none), ok: false)
    }
    let truth = evaluation.distance
    var offsets = rng.shuffled([-2, -1, 1, 2])
    var options = [truth]
    while options.count < 4 && !offsets.isEmpty {
      let value = truth + offsets.removeFirst()
      if value >= 1 && !options.contains(value) { options.append(value) }
    }
    var extra = truth + 3
    while options.count < 4 {
      options.append(extra)
      extra += 1
    }
    options.sort()
    var explanation = "You hold \(14 - truth) of the 14 tiles this hand needs, so it's \(awayText(truth))."
    if !evaluation.missing.isEmpty {
      explanation += " Missing: \(missingText(evaluation.missing))."
    }
    let flexible = evaluation.missing.filter(\.jokerOK)
    if !flexible.isEmpty {
      explanation += " A joker can stand in for the " + flexible.prefix(2).map(\.tile.name).joined(separator: " or ") + "."
    }
    let exercise = Exercise(
      id: id, prompt: "How many tiles away is this hand?", tiles: hand, lines: [line],
      choices: options.map { .number($0) },
      key: .choices(correct: [options.firstIndex(of: truth) ?? 0], answer: "\(truth)", explanation: explanation))
    return Built(exercise: exercise, ok: range.contains(truth) && options.count == 4)
  }

  static func neededTile(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    guard let lineIndex = rng.element(of: analyzer.usableLineIndexes) else {
      return Built(exercise: Exercise(id: id, prompt: "Which tile gets you closer?", key: .none), ok: false)
    }
    let line = analyzer.card.lines[lineIndex]
    let planned: Int
    switch id.difficulty {
    case 1: planned = rng.int(in: 1...3)
    case 2: planned = rng.int(in: 2...4)
    default: planned = rng.int(in: 3...5)
    }
    guard let hand = nearHand(analyzer, lineIndex: lineIndex, distance: planned, jokers: 0, rng: &rng),
      let base = analyzer.evaluation(at: lineIndex, tiles: hand)
    else {
      return Built(exercise: Exercise(id: id, prompt: "Which tile gets you closer?", key: .none), ok: false)
    }
    // Which single tiles help? Jokers are left out so the question stays about real tiles.
    var helpful: [Tile] = []
    var unhelpful: [Tile] = []
    for tile in Tile.allCases where tile != .joker {
      let held = hand.counts[tile] ?? 0
      guard held < tile.copies else { continue }
      let after = analyzer.distance(at: lineIndex, tiles: hand + [tile]) ?? base.distance
      if after < base.distance { helpful.append(tile) } else { unhelpful.append(tile) }
    }
    guard let right = rng.element(of: helpful) else {
      return Built(exercise: Exercise(id: id, prompt: "Which tile gets you closer?", key: .none), ok: false)
    }
    var wrong: [Tile]
    let inLine = Set(analyzer.targets(at: lineIndex).flatMap(\.tiles))
    switch id.difficulty {
    case 1:
      wrong = rng.shuffled(unhelpful.filter { !inLine.contains($0) })
    case 2:
      wrong = rng.shuffled(unhelpful.filter { !inLine.contains($0) }).prefix(1)
        + rng.shuffled(unhelpful.filter { inLine.contains($0) })
    default:
      var near: [Tile] = []
      if let value = right.numberValue {
        near = unhelpful.filter { $0.numberValue == value || ($0.suitValue == right.suitValue && abs(($0.numberValue ?? -9) - value) == 1) }
      }
      wrong = rng.shuffled(near) + rng.shuffled(unhelpful.filter { inLine.contains($0) })
    }
    wrong = wrong.filter { $0 != right }
    for tile in rng.shuffled(unhelpful) where wrong.count < 3 && !wrong.contains(tile) { wrong.append(tile) }
    let options = rng.shuffled([right] + Array(wrong.prefix(3)))
    let rightIndex = options.firstIndex(of: right) ?? 0
    let outcome = base.distance - 1 == 0 ? "Mahjong" : awayText(base.distance - 1)
    let explanation =
      "The \(right.name) is one the hand needs: it takes you from \(awayText(base.distance)) to \(outcome). The other tiles do nothing for \(line.displayName)."
    let exercise = Exercise(
      id: id, prompt: "Which tile gets you closer?", tiles: hand, lines: [line],
      choices: options.map { .tile($0) },
      key: .choices(correct: [rightIndex], answer: right.name, explanation: explanation))
    return Built(exercise: exercise, ok: options.count == 4)
  }
}
