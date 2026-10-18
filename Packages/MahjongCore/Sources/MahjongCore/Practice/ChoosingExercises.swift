import Foundation

/// `pickHand`, `passOne`, `passThree`, `keepOrPass` and `callIt` (SPEC §18.3): playing a hand.
enum ChoosingExercises {
  private static func yesNo() -> [Choice] { [.yesNo(true), .yesNo(false)] }

  private static func empty(_ id: ExerciseID, _ prompt: String) -> Built {
    Built(exercise: Exercise(id: id, prompt: prompt, key: .none), ok: false)
  }

  // MARK: pickHand

  static func pickHand(_ id: ExerciseID, analyzer: Analyzer, deal seed: UInt64, rng: inout SeededRandom) -> Built {
    let prompt = "Which hand would you aim for?"
    let lines = analyzer.card.lines
    if id.difficulty >= 3 {
      let hand = Wall.deal(seed: seed).hand.sortedForDisplay()
      let exercise = Exercise(
        id: id, prompt: prompt, tiles: hand, choices: lines.map { .line($0) }, key: .pickHand(restricted: false))
      return Built(exercise: exercise, ok: true)
    }

    let easy = id.difficulty == 1
    guard let deal = Exercises.stackedDeal(analyzer, rng: &rng, keep: easy ? 9 : 7) else { return empty(id, prompt) }
    let results = analyzer.analyze(PlayerView(rack: deal.hand))
    guard let best = results.first(where: { $0.best.possible }) else { return empty(id, prompt) }
    let others = results.filter { $0.line.id != best.line.id && $0.best.possible }
    let distance = best.best.distance

    let offeredOthers: [LineResult]
    var ok: Bool
    if easy {
      let elsewhere = others.filter { $0.line.section != best.line.section }
      ok = elsewhere.allSatisfy { $0.best.distance >= distance + 2 } && elsewhere.count >= 2
      var pool = rng.shuffled(elsewhere.filter { $0.best.distance >= distance + 2 })
      var chosen: [LineResult] = []
      var sections = Set<String>()
      for result in pool where chosen.count < 2 && sections.insert(result.line.section).inserted {
        chosen.append(result)
      }
      pool = pool.filter { candidate in !chosen.contains { $0.line.id == candidate.line.id } }
      while chosen.count < 2, let next = pool.first {
        chosen.append(next)
        pool.removeFirst()
      }
      offeredOthers = chosen
      ok = ok && chosen.count == 2
    } else {
      let farther = others.filter { $0.best.distance > distance }
      let near = rng.shuffled(farther.filter { $0.best.distance <= distance + 3 })
      let rest = rng.shuffled(farther.filter { $0.best.distance > distance + 3 })
      offeredOthers = Array((Array(near.prefix(2)) + rest + near.dropFirst(2)).prefix(4))
      ok = offeredOthers.count == 4
    }
    let offered = rng.shuffled([best.line] + offeredOthers.map(\.line))
    let exercise = Exercise(
      id: id, prompt: prompt, tiles: deal.hand, choices: offered.map { .line($0) }, key: .pickHand(restricted: true))
    return Built(exercise: exercise, ok: ok)
  }

  // MARK: passOne

  static func passOne(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    let prompt = "Pass one tile you don't need."
    let useless: Int
    switch id.difficulty {
    case 1: useless = 4
    case 2: useless = 2
    default: useless = 1
    }
    guard
      let deal = Exercises.stackedDeal(
        analyzer, rng: &rng, keep: 13 - useless, jokers: id.difficulty >= 3 ? 1 : 0),
      let evaluation = analyzer.evaluation(at: deal.lineIndex, tiles: deal.hand)
    else { return empty(id, prompt) }
    let line = analyzer.card.lines[deal.lineIndex]
    let spare = evaluation.unusedRack.filter { $0 != .joker }.count
    let ok = id.difficulty == 1 ? spare >= 3 : spare == useless
    let exercise = Exercise(
      id: id, prompt: prompt, tiles: deal.hand, lines: [line], selectCount: 1,
      caption: "Your target hand", key: .passOne(lineIndex: deal.lineIndex))
    return Built(exercise: exercise, ok: ok)
  }

  // MARK: passThree

  static func passThree(_ id: ExerciseID, analyzer: Analyzer, deal seed: UInt64, rng: inout SeededRandom) -> Built {
    let prompt = "Pass three tiles."
    let hand: [Tile]
    if id.difficulty == 1 {
      guard let deal = Exercises.stackedDeal(analyzer, rng: &rng, keep: 9) else { return empty(id, prompt) }
      hand = deal.hand
    } else {
      hand = Wall.deal(seed: seed).hand.sortedForDisplay()
    }
    let results = analyzer.analyze(PlayerView(rack: hand))
    let top = PassTop(results: results)
    let utilities = top.passableUtilities(hand: hand)
    let threshold = top.threshold(hand: hand) ?? 0
    var ok: Bool
    switch id.difficulty {
    case 1, 2:
      ok = utilities.count >= 3 && threshold <= PassTop.tolerance
    default:
      let held = hand.counts
      let trap = Tile.allCases.contains { tile in
        guard tile != .joker, held[tile] == 1 else { return false }
        let u = top.utility(of: tile, instance: 0)
        return u > threshold + PassTop.tolerance && u < 1.0 - PassTop.tolerance
      }
      ok = trap && threshold <= 0.5
    }
    let hintLines = id.difficulty == 1 ? results.filter { $0.best.possible }.prefix(2).map(\.line) : []
    let exercise = Exercise(
      id: id, prompt: prompt, tiles: hand, lines: Array(hintLines), selectCount: 3,
      caption: id.difficulty == 1 ? "Your two closest hands" : nil, key: .passThree)
    return Built(exercise: exercise, ok: ok)
  }

  // MARK: keepOrPass

  static func keepOrPass(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    let prompt = "Keep it or pass it?"
    guard let deal = Exercises.stackedDeal(analyzer, rng: &rng, keep: id.difficulty == 1 ? 10 : 9),
      let evaluation = analyzer.evaluation(at: deal.lineIndex, tiles: deal.hand)
    else { return empty(id, prompt) }
    let line = analyzer.card.lines[deal.lineIndex]
    let held = deal.hand.counts
    let types = Tile.allCases.filter { (held[$0] ?? 0) > 0 && $0 != .joker }
    let used = types.filter { (evaluation.usedRack[$0] ?? 0) > 0 }
    let spare = types.filter { (evaluation.usedRack[$0] ?? 0) == 0 }
    let inLine = Set(analyzer.targets(at: deal.lineIndex).flatMap(\.tiles))

    func nearMiss(_ tile: Tile) -> Bool {
      guard let value = tile.numberValue else { return false }
      return used.contains { other in
        other.numberValue == value && other.suitValue != tile.suitValue
          || other.suitValue == tile.suitValue && abs((other.numberValue ?? -9) - value) == 1
      }
    }
    let keepers = rng.int(in: 2...3)
    let passers = 5 - keepers
    let orderedSpare: [Tile]
    if id.difficulty == 1 {
      let clear = rng.shuffled(spare.filter { !inLine.contains($0) })
      orderedSpare = clear + rng.shuffled(spare.filter { inLine.contains($0) })
    } else if id.difficulty == 2 {
      orderedSpare = rng.shuffled(spare)
    } else {
      let near = rng.shuffled(spare.filter(nearMiss))
      orderedSpare = near + rng.shuffled(spare.filter { !nearMiss($0) })
    }
    let chosenKeep = Array(rng.shuffled(used).prefix(keepers))
    let chosenPass = Array(orderedSpare.prefix(passers))
    var ok = chosenKeep.count == keepers && chosenPass.count == passers
    if id.difficulty == 1 { ok = ok && chosenPass.allSatisfy { !inLine.contains($0) } }
    if id.difficulty == 3 { ok = ok && chosenPass.filter(nearMiss).count >= 2 }
    let queue = rng.shuffled(chosenKeep + chosenPass)
    let keeps = queue.map { chosenKeep.contains($0) }
    let explanations = queue.map { tile in
      chosenKeep.contains(tile)
        ? "Keep the \(tile.name): \(line.displayName) uses it."
        : "Pass the \(tile.name): \(line.displayName) doesn't use it."
    }
    let exercise = Exercise(
      id: id, prompt: prompt, tiles: deal.hand, lines: [line], queue: queue,
      caption: "Your target hand", key: .keepOrPass(keeps: keeps, explanations: explanations))
    return Built(exercise: exercise, ok: ok && queue.count == 5)
  }

  // MARK: callIt

  private enum Scenario { case exposeYes, mahjongYes, useless, pair, concealed, nearMiss }

  static func callIt(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    let prompt = "Call it?"
    let scenarios: [Scenario]
    switch id.difficulty {
    case 1: scenarios = [.exposeYes, .exposeYes, .useless]
    case 2: scenarios = [.exposeYes, .mahjongYes, .useless, .pair]
    default: scenarios = [.exposeYes, .mahjongYes, .pair, .concealed, .nearMiss]
    }
    guard let scenario = rng.element(of: scenarios) else { return empty(id, prompt) }

    let wantConcealed = scenario == .concealed
    var candidates = analyzer.usableLineIndexes.filter { analyzer.card.lines[$0].concealed == wantConcealed }
    if candidates.isEmpty { candidates = analyzer.usableLineIndexes }
    guard let lineIndex = rng.element(of: candidates),
      let target = analyzer.randomTarget(at: lineIndex, rng: &rng)
    else { return empty(id, prompt) }
    let line = analyzer.card.lines[lineIndex]

    var hand: [Tile] = []
    var discard: Tile = .flower
    let ownGroups = target.groups.indices.filter { target.groups[$0].jokerOK }
    let pairGroups = target.groups.indices.filter { target.groups[$0].count <= 2 }

    func build(around groupIndex: Int, discarding tile: Tile) {
      let group = target.groups[groupIndex]
      let have = Array(repeating: group.tile, count: group.count - 1)
      let rest = rng.shuffled(
        target.groups.indices.filter { $0 != groupIndex }.flatMap {
          Array(repeating: target.groups[$0].tile, count: target.groups[$0].count)
        })
      let kept = have + rest.prefix(8)
      hand = kept + Exercises.noiseTiles(13 - kept.count, besides: kept, jokers: false, rng: &rng)
      discard = tile
    }

    switch scenario {
    case .mahjongYes:
      let tiles = rng.shuffled(target.tiles)
      hand = Array(tiles.dropFirst())
      discard = tiles[0]
    case .exposeYes, .concealed:
      guard let g = rng.element(of: ownGroups) else { return empty(id, prompt) }
      build(around: g, discarding: target.groups[g].tile)
    case .pair:
      guard let g = rng.element(of: pairGroups) ?? rng.element(of: ownGroups) else { return empty(id, prompt) }
      build(around: g, discarding: target.groups[g].tile)
    case .nearMiss:
      guard let g = rng.element(of: ownGroups) else { return empty(id, prompt) }
      let tile = target.groups[g].tile
      var other = tile
      if let value = tile.numberValue, let suit = tile.suitValue {
        other = .number(value, Suit.allCases.filter { $0 != suit }.first ?? suit)
      }
      build(around: g, discarding: other)
    case .useless:
      guard let g = rng.element(of: ownGroups) else { return empty(id, prompt) }
      build(around: g, discarding: .flower)
      let inLine = Set(analyzer.targets(at: lineIndex).flatMap(\.tiles))
      let unrelated = Tile.allCases.filter { !inLine.contains($0) && $0 != .joker && !hand.contains($0) }
      discard = rng.element(of: unrelated) ?? .wind(.north)
    }
    hand = hand.sortedForDisplay()

    let view = PlayerView(rack: hand)
    let best = analyzer.analyze(view).first { $0.best.possible }
    let verdict = analyzer.checkCall(view, tile: discard).first {
      switch $0 {
      case .mahjong(let l), .expose(let l, _, _): return l.id == line.id
      }
    }
    var yes = false
    var explanation: String
    switch verdict {
    case .mahjong:
      yes = true
      explanation = "Yes! The \(discard.name) is the last tile \(line.displayName) needs, so you can call it to win."
    case .expose(_, let size, let newDistance):
      yes = true
      explanation =
        "Yes. You can call the \(discard.name) and show a \(groupNoun(size)), which puts you \(awayText(newDistance)) from \(line.displayName)."
    case nil:
      if line.concealed {
        explanation = "No. \(line.displayName) is a concealed hand, so you can only call a discard to win."
      } else if pairGroups.contains(where: { target.groups[$0].tile == discard }) {
        explanation =
          "No. You can only call a discard to make a set of three or more tiles, or to win. The \(discard.name) would only make a pair."
      } else {
        explanation =
          "No. The \(discard.name) doesn't help \(line.displayName): you can only call a tile that makes a set of three or more, or wins."
      }
    }
    let intended = scenario == .exposeYes || scenario == .mahjongYes
    let seat = rng.element(of: ["East", "South", "West", "North"]) ?? "East"
    let exercise = Exercise(
      id: id, prompt: "\(seat) discards the \(discard.name). Call it?", tiles: hand, lines: [line],
      choices: yesNo(), discard: discard, caption: "Your closest hand",
      key: .choices(correct: [yes ? 0 : 1], answer: yes ? "Yes" : "No", explanation: explanation))
    let ok = yes == intended && best?.line.id == line.id
    return Built(exercise: exercise, ok: ok)
  }
}
