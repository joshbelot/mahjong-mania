import Foundation

/// Generates and grades Practice questions (SPEC §18.3). Everything is deterministic in
/// `(type, seed, difficulty, focus)` and the card, so the same ID always gives the same question.
public enum Exercises {
  /// How many deals are tried before settling for the last one (SPEC §18.3.1).
  public static let maxAttempts = 300

  private static func salt(_ type: ExerciseType) -> UInt64 {
    let index = UInt64(ExerciseType.allCases.firstIndex(of: type) ?? 0) &+ 1
    return index &* 0x9E37_79B9_7F4A_7C15
  }

  public static func make(_ id: ExerciseID, card: Card) -> Exercise {
    make(id, analyzer: Analyzer.cached(for: card.lines.isEmpty ? PracticeCard.card : card))
  }

  public static func make(_ id: ExerciseID, analyzer: Analyzer) -> Exercise {
    makeWithStatus(id, analyzer: analyzer).exercise
  }

  /// The exercise and whether it passed the deal filter (false = the last attempt was used anyway).
  static func makeWithStatus(_ id: ExerciseID, analyzer: Analyzer) -> (exercise: Exercise, passedFilter: Bool) {
    var last: Built?
    var seed = id.seed
    var generator = SeededRandom(seed: id.seed)
    for attempt in 0..<maxAttempts {
      if attempt > 0 { seed = generator.next() }
      var rng = SeededRandom(seed: seed ^ salt(id.type) ^ (UInt64(id.difficulty) << 56))
      let built = build(id, analyzer: analyzer, seed: seed, rng: &rng)
      if built.ok { return (built.exercise, true) }
      last = built
    }
    return (last?.exercise ?? Exercise(id: id, prompt: "", key: .none), false)
  }

  private static func build(_ id: ExerciseID, analyzer: Analyzer, seed: UInt64, rng: inout SeededRandom) -> Built {
    switch id.type {
    case .nameTile: return TileExercises.nameTile(id, rng: &rng)
    case .findTile: return TileExercises.findTile(id, rng: &rng)
    case .groupName: return TileExercises.groupName(id, rng: &rng)
    case .matchesLine: return CardReadingExercises.matchesLine(id, analyzer: analyzer, rng: &rng)
    case .whichHand: return CardReadingExercises.whichHand(id, analyzer: analyzer, rng: &rng)
    case .jokerLegal: return CardReadingExercises.jokerLegal(id, analyzer: analyzer, rng: &rng)
    case .howFar: return DistanceExercises.howFar(id, analyzer: analyzer, rng: &rng)
    case .neededTile: return DistanceExercises.neededTile(id, analyzer: analyzer, rng: &rng)
    case .pickHand: return ChoosingExercises.pickHand(id, analyzer: analyzer, deal: seed, rng: &rng)
    case .passOne: return ChoosingExercises.passOne(id, analyzer: analyzer, rng: &rng)
    case .passThree: return ChoosingExercises.passThree(id, analyzer: analyzer, deal: seed, rng: &rng)
    case .keepOrPass: return ChoosingExercises.keepOrPass(id, analyzer: analyzer, rng: &rng)
    case .callIt: return ChoosingExercises.callIt(id, analyzer: analyzer, rng: &rng)
    }
  }

  // MARK: Grading

  public static func grade(_ exercise: Exercise, answer: Answer, card: Card) -> Grade {
    grade(exercise, answer: answer, analyzer: Analyzer.cached(for: card.lines.isEmpty ? PracticeCard.card : card))
  }

  public static func grade(_ exercise: Exercise, answer: Answer, analyzer: Analyzer) -> Grade {
    let wrong = Grade(correct: false, correctAnswer: "", explanation: "", score: 0, outOf: 1)
    switch exercise.key {
    case .none:
      return wrong

    case .choices(let correct, let text, let explanation):
      guard case .choice(let index) = answer else { return wrong }
      let right = correct.contains(index)
      return Grade(
        correct: right, correctAnswer: text, explanation: explanation, score: right ? 1 : 0, outOf: 1)

    case .pickHand(let restricted):
      guard case .choice(let index) = answer, exercise.choices.indices.contains(index),
        case .line(let picked) = exercise.choices[index]
      else { return wrong }
      let offered: [CardLine]? =
        restricted
        ? exercise.choices.compactMap {
          if case .line(let line) = $0 { return line }
          return nil
        } : nil
      guard let result = PickScorer.grade(hand: exercise.tiles, picked: picked, offered: offered, analyzer: analyzer)
      else { return wrong }
      let names = result.best.map(\.line.displayName)
      return Grade(
        correct: result.correct, correctAnswer: names.joined(separator: " or "),
        explanation: result.explanation, score: result.correct ? 1 : 0, outOf: 1)

    case .passOne(let lineIndex):
      guard case .tiles(let positions) = answer, positions.count == 1, exercise.canSelect(position: positions[0]),
        let evaluation = analyzer.evaluation(at: lineIndex, tiles: exercise.tiles)
      else { return wrong }
      let line = analyzer.card.lines[lineIndex]
      let held = exercise.tiles.counts
      let tile = exercise.tiles[positions[0]]
      let spare = (held[tile] ?? 0) > (evaluation.usedRack[tile] ?? 0)
      let examples = evaluation.unusedRack.filter { $0 != .joker }
      var uniqueExamples: [Tile] = []
      for tile in examples where !uniqueExamples.contains(tile) { uniqueExamples.append(tile) }
      let answerText = uniqueExamples.prefix(2).map(\.name).joined(separator: " or ")
      let explanation =
        spare
        ? "Right: \(line.displayName) has no use for your \(tile.name), so it's a good one to pass."
        : "Your \(tile.name) is part of \(line.displayName). Pass a tile the hand doesn't use, like the \(answerText)."
      return Grade(correct: spare, correctAnswer: answerText, explanation: explanation, score: spare ? 1 : 0, outOf: 1)

    case .passThree:
      guard case .tiles(let positions) = answer,
        let outcome = PassScorer.score(hand: exercise.tiles, selection: positions, analyzer: analyzer)
      else { return Grade(correct: false, correctAnswer: "", explanation: "Pick three tiles that are not jokers.", score: 0, outOf: 3) }
      return Grade(
        correct: outcome.score == 3, correctAnswer: outcome.enginePasses.map(\.name).joined(separator: ", "),
        explanation: outcome.explanation, score: outcome.score, outOf: 3)

    case .keepOrPass(let keeps, let explanations):
      guard case .decisions(let decisions) = answer, decisions.count == keeps.count else {
        return Grade(correct: false, correctAnswer: "", explanation: "", score: 0, outOf: keeps.count)
      }
      let rightCount = zip(decisions, keeps).filter { $0 == $1 }.count
      let mistakes = zip(decisions, keeps).enumerated().filter { $1.0 != $1.1 }.map { explanations[$0.offset] }
      let keepNames = zip(exercise.queue, keeps).filter { $1 }.map { $0.0.name }
      let passNames = zip(exercise.queue, keeps).filter { !$1 }.map { $0.0.name }
      let all = rightCount == keeps.count
      return Grade(
        correct: all, correctAnswer: "Keep: \(keepNames.joined(separator: ", ")). Pass: \(passNames.joined(separator: ", ")).",
        explanation: all ? "All \(keeps.count) right." : mistakes.prefix(2).joined(separator: " "),
        score: rightCount, outOf: keeps.count)
    }
  }

  // MARK: Hints

  public static func hint(for exercise: Exercise, card: Card) -> Hint {
    hint(for: exercise, analyzer: Analyzer.cached(for: card.lines.isEmpty ? PracticeCard.card : card))
  }

  public static func hint(for exercise: Exercise, analyzer: Analyzer) -> Hint {
    var rng = SeededRandom(seed: exercise.id.seed ^ 0x48_494E_54)
    func removal(wrong: [Int]) -> [Int] {
      guard exercise.choices.count > 2 else { return [] }
      return Array(rng.shuffled(wrong).prefix((wrong.count + 1) / 2)).sorted()
    }
    let empty = Hint(text: "", removeChoices: [], highlightTiles: [], lines: [])

    switch exercise.key {
    case .choices(let correct, _, _):
      let wrong = exercise.choices.indices.filter { !correct.contains($0) }
      var hint = empty
      hint.removeChoices = removal(wrong: wrong)
      switch exercise.id.type {
      case .nameTile:
        hint.text = exercise.tiles.first.map { "It's one of the \($0.familyName) tiles." } ?? ""
      case .findTile:
        if let index = correct.first, case .tile(let tile) = exercise.choices[index] {
          hint.text = "Look for a \(tile.familyName) tile."
        }
      case .groupName:
        hint.text = "Count the tiles: there are \(exercise.tiles.count)."
      case .matchesLine:
        hint.text =
          exercise.id.focus == ExerciseFocus.colours
          ? "Tiles in the same colour on the pattern must be the same suit; different colours, different suits."
          : "Go group by group and compare each with the pattern."
      case .whichHand:
        hint.text = "Look for the hand whose pattern has the same groups as these tiles."
      case .jokerLegal:
        hint.text = "Jokers may only stand in for tiles in groups of three or more."
      case .neededTile:
        hint.text = "Look at the pattern: which tile does the hand still need?"
      case .callIt:
        hint.text = "You can call a discard to make a set of three or more, or to win."
      default:
        hint.text = "Take your time."
      }
      if exercise.id.type == .howFar, let line = exercise.line, let index = analyzer.lineIndex(of: line),
        let evaluation = analyzer.evaluation(at: index, tiles: exercise.tiles)
      {
        hint.highlightTiles = highlight(exercise.tiles, using: evaluation.usedRack)
        hint.text = "The highlighted tiles already fit the hand. Count the ones that don't."
      }
      return hint

    case .pickHand:
      let results = analyzer.analyze(PlayerView(rack: exercise.tiles))
      var distances: [String: Int] = [:]
      for result in results { distances[result.line.id] = result.best.possible ? result.best.distance : 99 }
      let scored = exercise.choices.indices.compactMap { index -> (Int, Int)? in
        guard case .line(let line) = exercise.choices[index] else { return nil }
        return (index, distances[line.id] ?? 99)
      }
      let best = scored.map(\.1).min() ?? 0
      let wrong = scored.filter { $0.1 > best }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
      var hint = empty
      hint.removeChoices = Array(wrong.prefix((wrong.count + 1) / 2).map(\.0)).sorted()
      hint.text = "Look for the hand that uses the most of your tiles."
      return hint

    case .passOne(let lineIndex):
      var hint = empty
      if let evaluation = analyzer.evaluation(at: lineIndex, tiles: exercise.tiles) {
        hint.highlightTiles = highlight(exercise.tiles, using: evaluation.usedRack)
      }
      hint.text = "The highlighted tiles are part of the hand. Pass one that isn't."
      return hint

    case .passThree:
      var hint = empty
      hint.lines = analyzer.analyze(PlayerView(rack: exercise.tiles)).filter { $0.best.possible }.prefix(2).map(\.line)
      hint.text = "Pass tiles that none of these hands use."
      return hint

    case .keepOrPass:
      var hint = empty
      hint.text = "Does the hand's pattern include this tile?"
      return hint

    case .none:
      return empty
    }
  }

  /// Positions in `tiles` of the copies that `used` says fit (first copies of each tile).
  private static func highlight(_ tiles: [Tile], using used: TileCounts) -> [Int] {
    var remaining = used
    var positions: [Int] = []
    for (position, tile) in tiles.enumerated() where (remaining[tile] ?? 0) > 0 {
      remaining[tile, default: 0] -= 1
      positions.append(position)
    }
    return positions
  }
}
