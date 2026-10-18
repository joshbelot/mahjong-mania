import Foundation

/// The kinds of question the Practice game asks (SPEC §18.3).
public enum ExerciseType: String, Codable, CaseIterable, Sendable {
  case nameTile, findTile, groupName, matchesLine, whichHand, jokerLegal,
    howFar, neededTile, pickHand, passOne, passThree, keepOrPass, callIt
}

/// Everything needed to rebuild an exercise: `(type, seed, difficulty)` plus an optional `focus` that
/// narrows what a lesson asks about (for example "only winds and dragons"). `focus` 0 means no
/// restriction; its meaning is per type, see `ExerciseFocus`.
public struct ExerciseID: Hashable, Codable, Sendable {
  public var type: ExerciseType
  public var seed: UInt64
  public var difficulty: Int
  public var focus: Int

  public init(type: ExerciseType, seed: UInt64, difficulty: Int, focus: Int = 0) {
    self.type = type
    self.seed = seed
    self.difficulty = max(1, min(3, difficulty))
    self.focus = focus
  }

  private enum CodingKeys: String, CodingKey { case type, seed, difficulty, focus }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    type = try c.decode(ExerciseType.self, forKey: .type)
    seed = try c.decode(UInt64.self, forKey: .seed)
    difficulty = max(1, min(3, try c.decode(Int.self, forKey: .difficulty)))
    focus = try c.decodeIfPresent(Int.self, forKey: .focus) ?? 0
  }
}

/// The lesson-level restrictions a `focus` value can ask for.
public enum ExerciseFocus {
  /// `nameTile` / `findTile`
  public static let numbers = 1
  public static let windsAndDragons = 2
  public static let flowersJokersSoap = 3
  /// `matchesLine`
  public static let colours = 1
  public static let exposedConcealed = 2
}

public enum Choice: Hashable, Sendable {
  case text(String)
  case tile(Tile)
  case line(CardLine)
  case number(Int)
  case yesNo(Bool)
}

public enum Answer: Hashable, Sendable {
  /// Index into `Exercise.choices`.
  case choice(Int)
  /// Positions in `Exercise.tiles` (passOne, passThree).
  case tiles([Int])
  /// One decision per tile of `Exercise.queue`: `true` = keep (keepOrPass).
  case decisions([Bool])
}

/// What the screen renders for one question.
public struct Exercise: Sendable {
  public var id: ExerciseID
  public var prompt: String
  /// The tiles shown, in display order (flat).
  public var tiles: [Tile] = []
  /// The same tiles in clusters (one per group of the hand); empty when the tiles are shown flat.
  public var groups: [[Tile]] = []
  /// Card lines shown as patterns. `line` is the first.
  public var lines: [CardLine] = []
  public var choices: [Choice] = []
  /// Tiles to select: 1 for `passOne`, 3 for `passThree`, otherwise 0.
  public var selectCount: Int = 0
  /// `keepOrPass`: the tiles to decide on, one at a time.
  public var queue: [Tile] = []
  /// `callIt`: the tile just thrown.
  public var discard: Tile?
  /// A short sentence shown as a caption under the prompt (for example "Your target: …").
  public var caption: String?
  let key: ExerciseKey

  public var line: CardLine? { lines.first }

  /// For multiple-choice exercises: is choice `index` a right answer? Nil when the exercise isn't one
  /// (selection exercises). Used by UI tests to find the right button; the app never shows it.
  public func isChoiceCorrect(_ index: Int) -> Bool? {
    switch key {
    case .choices(let correct, _, _): return correct.contains(index)
    default: return nil
    }
  }

  /// `keepOrPass`: should the `queueIndex`-th tile be kept? Nil for other exercises.
  public func shouldKeep(queueIndex: Int) -> Bool? {
    if case .keepOrPass(let keeps, _) = key, keeps.indices.contains(queueIndex) { return keeps[queueIndex] }
    return nil
  }

  /// Jokers may never be passed.
  public func canSelect(position: Int) -> Bool {
    tiles.indices.contains(position) && tiles[position] != .joker
  }
}

/// A type-specific help for the lightbulb button (path lessons only).
public struct Hint: Sendable {
  public var text: String
  /// Indices of `choices` that are wrong and can be greyed out.
  public var removeChoices: [Int]
  /// Positions in `tiles` to highlight.
  public var highlightTiles: [Int]
  /// Extra lines to show as patterns.
  public var lines: [CardLine]
}

public struct Grade: Sendable {
  public var correct: Bool
  public var correctAnswer: String
  public var explanation: String
  /// Partial credit: `score` of `outOf` (passThree tiles, keepOrPass tiles); otherwise 1/1 or 0/1.
  public var score: Int
  public var outOf: Int
}

/// The answer key stored with an exercise at generation time.
enum ExerciseKey: Sendable {
  case none
  /// Choice indexes that are right, and the text shown as the correct answer.
  case choices(correct: Set<Int>, answer: String, explanation: String)
  /// `pickHand`: `restricted` = only the offered lines compete (d1, d2); otherwise the whole card.
  case pickHand(restricted: Bool)
  case passOne(lineIndex: Int)
  case passThree
  case keepOrPass(keeps: [Bool], explanations: [String])
}
