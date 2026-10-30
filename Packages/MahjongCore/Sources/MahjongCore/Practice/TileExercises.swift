import Foundation

/// `groupName` (SPEC §18.3): the size of a group. (Tile facts are in `TileFacts`.)
enum TileExercises {
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
    let all = id.difficulty == 1 ? (1...4).map(groupNoun) : (1...6).map(groupNoun)
    // Shuffled: in order, the position of the answer would be the number of tiles.
    let nouns = rng.shuffled(all)
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
      key: .choices(correct: [nouns.firstIndex(of: name) ?? 0], answer: name, explanation: explanation))
    return Built(exercise: exercise, ok: all.count > size - 1)
  }
}
