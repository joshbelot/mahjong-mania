import Foundation

/// `nameTile`, `findTile` and `groupName` (SPEC §18.3): recognising tiles and the size of a group.
enum TileExercises {
  /// The tiles a lesson focus draws its answers from.
  static func pool(focus: Int) -> [Tile] {
    switch focus {
    case ExerciseFocus.numbers:
      return Tile.allCases.filter { $0.numberValue != nil }
    case ExerciseFocus.windsAndDragons:
      return Tile.allCases.filter {
        if case .wind = $0 { return true }
        return $0 == .dragon(.red) || $0 == .dragon(.green)
      }
    case ExerciseFocus.flowersJokersSoap:
      return [.flower, .joker, .dragon(.white)]
    default:
      return Tile.allCases
    }
  }

  /// `count` tiles that look alike enough to be wrong answers for `tile`, nastier at higher difficulty.
  static func distractors(for tile: Tile, count: Int, difficulty: Int, rng: inout SeededRandom) -> [Tile] {
    let all = Tile.allCases.filter { $0 != tile }
    let otherKinds = all.filter { $0.kind != tile.kind }
    let sameKind = all.filter { $0.kind == tile.kind }
    var buckets: [[Tile]]
    switch difficulty {
    case 1:
      let numbersElsewhere = otherKinds.filter { $0.numberValue != nil }
      buckets = [numbersElsewhere, otherKinds, otherKinds]
    case 2:
      let otherSuit = otherKinds.filter { $0.numberValue != nil }
      buckets = [sameKind.isEmpty ? otherKinds : sameKind, sameKind.isEmpty ? otherKinds : sameKind, otherSuit]
    default:
      var sameNumber: [Tile] = []
      var neighbours: [Tile] = []
      if let value = tile.numberValue, let suit = tile.suitValue {
        sameNumber = all.filter { $0.numberValue == value && $0.suitValue != suit }
        neighbours = [value - 1, value + 1].filter { (1...9).contains($0) }.map { .number($0, suit) }
        neighbours.append(Tile.matchingDragon(suit))
      } else if case .dragon = tile {
        let matching = Suit.allCases.first { Tile.matchingDragon($0) == tile }
        sameNumber = all.filter { $0.suitValue == matching && [1, 5, 9].contains($0.numberValue ?? 0) }
        neighbours = sameKind
      } else {
        neighbours = sameKind
        sameNumber = otherKinds.filter { $0.numberValue == nil }
      }
      buckets = [sameNumber, neighbours, sameKind.isEmpty ? otherKinds : sameKind]
    }
    buckets = buckets.map { rng.shuffled($0) }
    var result: [Tile] = []
    var progressed = true
    while result.count < count && progressed {
      progressed = false
      for bucket in buckets where result.count < count {
        if let next = bucket.first(where: { !result.contains($0) && $0 != tile }) {
          result.append(next)
          progressed = true
        }
      }
    }
    for other in rng.shuffled(all) where result.count < count && !result.contains(other) { result.append(other) }
    return Array(result.prefix(count))
  }

  static func nameTile(_ id: ExerciseID, rng: inout SeededRandom) -> Built {
    let pool = pool(focus: id.focus)
    let tile = rng.element(of: pool) ?? .flower
    let options = rng.shuffled([tile] + distractors(for: tile, count: 3, difficulty: id.difficulty, rng: &rng))
    let correct = options.firstIndex(of: tile) ?? 0
    let exercise = Exercise(
      id: id, prompt: "What is this tile?", tiles: [tile],
      choices: options.map { .text($0.name) },
      key: .choices(
        correct: [correct], answer: tile.name, explanation: "That's the \(tile.name). \(tile.teachingNote)"))
    return Built(exercise: exercise, ok: true)
  }

  static func findTile(_ id: ExerciseID, rng: inout SeededRandom) -> Built {
    let pool = pool(focus: id.focus)
    let tile = rng.element(of: pool) ?? .flower
    let options = rng.shuffled([tile] + distractors(for: tile, count: 5, difficulty: id.difficulty, rng: &rng))
    let correct = options.firstIndex(of: tile) ?? 0
    let exercise = Exercise(
      id: id, prompt: "Tap the \(tile.name).", tiles: [],
      choices: options.map { .tile($0) },
      key: .choices(
        correct: [correct], answer: tile.name, explanation: "That's the \(tile.name). \(tile.teachingNote)"))
    return Built(exercise: exercise, ok: true)
  }

  static func groupName(_ id: ExerciseID, rng: inout SeededRandom) -> Built {
    let naturals = Tile.allCases.filter { $0 != .joker && $0 != .flower }
    var size: Int
    var jokers = 0
    var tile: Tile
    switch id.difficulty {
    case 1:
      size = rng.int(in: 1...4)
      tile = rng.element(of: naturals) ?? .wind(.east)
    case 2:
      size = rng.int(in: 2...5)
      tile = rng.element(of: naturals) ?? .wind(.east)
      if size >= 3 { jokers = rng.int(in: 1...(size - 2)) }
    default:
      size = rng.int(in: 1...6)
      tile = rng.chance(40) ? .flower : (rng.element(of: naturals) ?? .wind(.east))
      let needed = max(0, size - tile.copies)
      jokers = size >= 3 && rng.chance(40) ? 1 : 0
      jokers = min(max(jokers, needed), max(0, size - 2))
    }
    let shown = Array(repeating: tile, count: size - jokers) + Array(repeating: Tile.joker, count: jokers)
    let nouns = id.difficulty == 1 ? (1...4).map(groupNoun) : (1...6).map(groupNoun)
    let name = groupNoun(size)
    var explanation = "\(size) of the same tile is a \(name)."
    if jokers > 0 {
      explanation = "A joker counts as the tile it stands in for, so \(size) tiles is a \(name)."
    }
    if size == 1 { explanation = "One tile on its own is a Single." }
    if size >= 5 { explanation += " Quints and Sextets appear on the card when jokers help." }
    let exercise = Exercise(
      id: id, prompt: "What is this group called?", tiles: shown, groups: [shown],
      choices: nouns.map { .text($0) },
      key: .choices(correct: [size - 1], answer: name, explanation: explanation))
    return Built(exercise: exercise, ok: nouns.count > size - 1)
  }
}
