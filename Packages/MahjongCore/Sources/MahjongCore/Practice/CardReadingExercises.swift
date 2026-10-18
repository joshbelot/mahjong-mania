import Foundation

/// `matchesLine`, `whichHand` and `jokerLegal` (SPEC §18.3): reading the card.
enum CardReadingExercises {
  private static func yesNo() -> [Choice] { [.yesNo(true), .yesNo(false)] }

  /// A winning hand for a random target of `lineIndex`, as groups (jokers inside their groups).
  private static func winningGroups(
    _ analyzer: Analyzer, lineIndex: Int, jokers: Int, rng: inout SeededRandom
  ) -> (groups: [[Tile]], target: Target)? {
    guard let target = analyzer.randomTarget(at: lineIndex, rng: &rng) else { return nil }
    return (Exercises.groupTiles(of: target, jokers: jokers, rng: &rng), target)
  }

  private static func suitVariableCount(_ line: CardLine) -> Int {
    guard let variant = line.variants.first else { return 0 }
    return Instantiate.variables(in: variant.groups).count
  }

  // MARK: Ways to break a hand

  private enum Mutation: CaseIterable { case wrongNumber, swapSuits, jokerInPair, wrongDragon, oneTile }

  /// Breaks a matching hand in one way; the caller checks that it really no longer matches.
  private static func mutate(
    _ groups: [[Tile]], _ kind: Mutation, rng: inout SeededRandom
  ) -> (groups: [[Tile]], why: String)? {
    var groups = groups
    switch kind {
    case .wrongNumber:
      let candidates = groups.indices.filter { groups[$0].first?.numberValue != nil }
      guard let i = rng.element(of: candidates), let old = groups[i].first,
        let value = old.numberValue, let suit = old.suitValue
      else { return nil }
      let options = (1...9).filter { $0 != value }
      guard let newValue = rng.element(of: options) else { return nil }
      let new = Tile.number(newValue, suit)
      groups[i] = groups[i].map { $0 == .joker ? $0 : new }
      return (groups, "In place of the \(old.name)s this hand has \(new.name)s, so the numbers don't match the pattern.")
    case .swapSuits:
      let candidates = groups.indices.filter { groups[$0].first?.suitValue != nil }
      let suitsInHand = Set(candidates.compactMap { groups[$0].first?.suitValue })
      guard suitsInHand.count >= 2, let i = rng.element(of: candidates),
        let old = groups[i].first, let suit = old.suitValue, let value = old.numberValue,
        let target = rng.element(of: suitsInHand.sorted { $0.rawValue < $1.rawValue }.filter { $0 != suit })
      else { return nil }
      groups[i] = groups[i].map { $0 == .joker ? $0 : .number(value, target) }
      return (
        groups,
        "Different colours on the pattern mean different suits. Here the \(suit.plainName) have been swapped for \(target.plainName), so two colours share a suit."
      )
    case .jokerInPair:
      let candidates = groups.indices.filter { groups[$0].count <= 2 && !groups[$0].contains(.joker) }
      guard let i = rng.element(of: candidates) else { return nil }
      groups[i][groups[i].count - 1] = .joker
      return (groups, "A joker is standing in for a tile of a pair, and jokers are never allowed in singles or pairs.")
    case .wrongDragon:
      let candidates = groups.indices.filter { if case .dragon = groups[$0].first { return true } else { return false } }
      guard let i = rng.element(of: candidates), let old = groups[i].first else { return nil }
      let options: [Tile] = [.dragon(.red), .dragon(.green), .dragon(.white)].filter { $0 != old }
      guard let new = rng.element(of: options) else { return nil }
      groups[i] = groups[i].map { $0 == .joker ? $0 : new }
      return (groups, "The pattern needs the \(old.name) here, but this hand has the \(new.name).")
    case .oneTile:
      let candidates = groups.indices.filter { !groups[$0].isEmpty }
      guard let i = rng.element(of: candidates), let j = rng.element(of: Array(groups[i].indices)),
        let replacement = rng.element(of: Tile.allCases.filter { $0 != groups[i][j] && $0 != .joker })
      else { return nil }
      let old = groups[i][j]
      groups[i][j] = replacement
      return (groups, "One tile is wrong: the \(replacement.name) is where the pattern needs the \(old.name).")
    }
  }

  private static func order(for difficulty: Int, focus: Int) -> [Mutation] {
    if focus == ExerciseFocus.colours { return [.swapSuits, .wrongNumber, .oneTile] }
    switch difficulty {
    case 1: return [.wrongNumber, .oneTile, .swapSuits, .jokerInPair, .wrongDragon]
    case 2: return [.swapSuits, .wrongNumber, .oneTile, .jokerInPair, .wrongDragon]
    default: return [.jokerInPair, .wrongDragon, .swapSuits, .oneTile, .wrongNumber]
    }
  }

  // MARK: matchesLine

  static func matchesLine(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    let usable = analyzer.usableLineIndexes
    var candidates = usable
    if id.focus == ExerciseFocus.colours {
      let coloured = usable.filter { suitVariableCount(analyzer.card.lines[$0]) >= 2 }
      if !coloured.isEmpty { candidates = coloured }
    }
    guard let lineIndex = rng.element(of: candidates) else {
      return Built(exercise: Exercise(id: id, prompt: "Does this hand match the line?", key: .none), ok: false)
    }
    let line = analyzer.card.lines[lineIndex]

    if id.focus == ExerciseFocus.exposedConcealed && rng.chance(50) {
      let exposed = !line.concealed
      let explanation =
        exposed
        ? "This hand is marked X: it is exposed, so you may call other players' discards to make sets and show them."
        : "This hand is marked C: it is concealed, so you may not call discards except for the very last tile that wins."
      let exercise = Exercise(
        id: id, prompt: "Can you call other players' discards to make sets for this hand?", lines: [line],
        choices: yesNo(), key: .choices(correct: [exposed ? 0 : 1], answer: exposed ? "Yes" : "No", explanation: explanation))
      return Built(exercise: exercise, ok: true)
    }

    let wantYes = rng.chance(50)
    let jokers: Int
    switch id.difficulty {
    case 1: jokers = 0
    case 2: jokers = rng.int(in: 0...1)
    default: jokers = rng.int(in: 0...2)
    }
    guard let (groups, target) = winningGroups(analyzer, lineIndex: lineIndex, jokers: jokers, rng: &rng) else {
      return Built(exercise: Exercise(id: id, prompt: "Does this hand match the line?", key: .none), ok: false)
    }

    var shownGroups = groups
    var why = ""
    var ok = true
    if !wantYes {
      var broken = false
      for kind in order(for: id.difficulty, focus: id.focus) where !broken {
        for _ in 0..<12 where !broken {
          guard let result = mutate(groups, kind, rng: &rng) else { continue }
          if !analyzer.matches(at: lineIndex, tiles: result.groups.flatMap { $0 }) {
            shownGroups = result.groups
            why = result.why
            broken = true
          }
        }
      }
      ok = broken
      if !broken { shownGroups = groups }
    }
    let flat = shownGroups.flatMap { $0 }
    let matches = analyzer.matches(at: lineIndex, tiles: flat)
    let grouped = id.difficulty == 1
    let display = grouped ? shownGroups : []
    let shownTiles = grouped ? flat : flat.sortedForDisplay()
    let explanation =
      matches
      ? "Yes, these tiles make \(line.displayName): "
        + Notation.describe(line.variants[target.variantIndex], shift: line.shift, concealed: line.concealed)
      : "No. " + why
    let exercise = Exercise(
      id: id, prompt: "Does this hand match the line?", tiles: shownTiles, groups: display, lines: [line],
      choices: yesNo(), key: .choices(correct: [matches ? 0 : 1], answer: matches ? "Yes" : "No", explanation: explanation))
    return Built(exercise: exercise, ok: ok && matches == wantYes)
  }

  // MARK: whichHand

  static func whichHand(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    var usable = analyzer.usableLineIndexes
    if id.difficulty >= 3 {
      // Hard hands always show a joker, so the line must have a group of three or more.
      let withJokers = usable.filter { index in
        analyzer.targets(at: index).first.map { $0.groups.contains { $0.jokerOK } } ?? false
      }
      if !withJokers.isEmpty { usable = withJokers }
    }
    guard let lineIndex = rng.element(of: usable) else {
      return Built(exercise: Exercise(id: id, prompt: "Which hand is this?", key: .none), ok: false)
    }
    let line = analyzer.card.lines[lineIndex]
    let jokers: Int
    switch id.difficulty {
    case 1: jokers = 0
    case 2: jokers = rng.int(in: 0...2)
    default: jokers = rng.int(in: 1...3)
    }
    guard let (groups, target) = winningGroups(analyzer, lineIndex: lineIndex, jokers: jokers, rng: &rng) else {
      return Built(exercise: Exercise(id: id, prompt: "Which hand is this?", key: .none), ok: false)
    }
    let flat = groups.flatMap { $0 }
    let others = usable.filter { $0 != lineIndex && !analyzer.matches(at: $0, tiles: flat) }
    let sameSection = rng.shuffled(others.filter { analyzer.card.lines[$0].section == line.section })
    let elsewhere = rng.shuffled(others.filter { analyzer.card.lines[$0].section != line.section })
    let wanted = id.difficulty + 1
    var picks: [Int] = []
    switch id.difficulty {
    case 1: picks = elsewhere + sameSection
    case 2: picks = Array(elsewhere.prefix(1)) + sameSection + elsewhere.dropFirst()
    default: picks = sameSection + elsewhere
    }
    let options = rng.shuffled([lineIndex] + picks.prefix(wanted - 1))
    let correct = options.firstIndex(of: lineIndex) ?? 0
    let grouped = id.difficulty == 1
    let explanation =
      "These tiles make \(line.displayName): "
      + Notation.describe(line.variants[target.variantIndex], shift: line.shift, concealed: line.concealed)
    let exercise = Exercise(
      id: id, prompt: "Which hand is this?", tiles: grouped ? flat : flat.sortedForDisplay(),
      groups: grouped ? groups : [], choices: options.map { .line(analyzer.card.lines[$0]) },
      key: .choices(correct: [correct], answer: line.displayName, explanation: explanation))
    return Built(exercise: exercise, ok: options.count == wanted)
  }

  // MARK: jokerLegal

  static func jokerLegal(_ id: ExerciseID, analyzer: Analyzer, rng: inout SeededRandom) -> Built {
    let usable = analyzer.usableLineIndexes.filter { index in
      analyzer.targets(at: index).first.map { target in target.groups.contains { $0.jokerOK && $0.count >= 3 } } ?? false
    }
    guard let lineIndex = rng.element(of: usable) else {
      return Built(exercise: Exercise(id: id, prompt: "Is this a legal Mahjong?", key: .none), ok: false)
    }
    let line = analyzer.card.lines[lineIndex]
    let wantLegal = rng.chance(50)
    var jokers: Int
    switch id.difficulty {
    case 1: jokers = 1
    case 2: jokers = rng.int(in: 2...3)
    default: jokers = rng.int(in: 3...5)
    }
    guard let built = winningGroups(analyzer, lineIndex: lineIndex, jokers: jokers, rng: &rng) else {
      return Built(exercise: Exercise(id: id, prompt: "Is this a legal Mahjong?", key: .none), ok: false)
    }
    var groups = built.groups
    jokers = groups.flatMap { $0 }.filter { $0 == .joker }.count
    var why = "Every joker is in a group of three or more tiles, so this is a legal \(line.displayName)."
    var ok = jokers >= 1
    if !wantLegal {
      let weak = groups.indices.filter { groups[$0].count <= 2 }
      if let i = rng.element(of: weak) {
        let tile = groups[i][0]
        groups[i][groups[i].count - 1] = .joker
        let place = groups[i].count == 1 ? "a single (the \(tile.name))" : "a pair of \(tile.name)s"
        why =
          "A joker is standing in for a tile in \(place). Jokers can only go in groups of three or more, so this is not a legal Mahjong."
      } else {
        ok = false
      }
    }
    let flat = groups.flatMap { $0 }
    let legal = analyzer.matches(at: lineIndex, tiles: flat)
    let exercise = Exercise(
      id: id, prompt: "Is this a legal Mahjong?", tiles: flat, groups: groups, lines: [line],
      choices: yesNo(), key: .choices(correct: [legal ? 0 : 1], answer: legal ? "Yes" : "No", explanation: why))
    return Built(exercise: exercise, ok: ok && legal == wantLegal)
  }
}
