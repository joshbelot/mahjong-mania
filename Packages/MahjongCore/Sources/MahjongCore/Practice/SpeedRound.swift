import Foundation

/// One Speed Round question (SPEC §18.8).
public enum SpeedQuestion: Sendable {
  /// Keep or pass `tile` for the target `line`, with the 13 tiles of the deal shown for context.
  case keepPass(line: CardLine, rack: [Tile], tile: Tile, keep: Bool, why: String)
  /// A name-the-tile or name-the-group question.
  case bonus(Exercise)
}

/// The endless supply of Speed Round questions for a seed: single keep-or-pass decisions against rotating
/// targets at difficulty 2, with a name-the-tile or name-the-group question mixed in from the 21st on.
public struct SpeedStream: Sendable {
  public static let warmUp = 20

  private let seed: UInt64
  private let analyzer: Analyzer
  private var index = 0
  private var keepIndex = 0
  private var block: Exercise?

  public init(seed: UInt64, analyzer: Analyzer) {
    self.seed = seed
    self.analyzer = analyzer
  }

  public var asked: Int { index }

  public mutating func next() -> SpeedQuestion {
    defer { index += 1 }
    let isBonus = index >= Self.warmUp && (index - Self.warmUp) % 4 == 3
    if isBonus {
      var generator = SeededRandom(seed: seed &+ UInt64(index) &* 0x9E37_79B9)
      let type: ExerciseType = ((index - Self.warmUp) / 4) % 2 == 0 ? .tileFact : .groupName
      let exercise = Exercises.make(ExerciseID(type: type, seed: generator.next(), difficulty: 2), analyzer: analyzer)
      return .bonus(exercise)
    }
    if keepIndex % 5 == 0 || block == nil {
      var generator = SeededRandom(seed: seed &+ UInt64(keepIndex / 5) &* 0xD1B5_4A32)
      block = Exercises.make(ExerciseID(type: .keepOrPass, seed: generator.next(), difficulty: 2), analyzer: analyzer)
    }
    defer { keepIndex += 1 }
    guard let block, let line = block.line else {
      return .bonus(Exercises.make(ExerciseID(type: .tileFact, seed: seed, difficulty: 2), analyzer: analyzer))
    }
    let position = keepIndex % max(1, block.queue.count)
    let tile = block.queue[position]
    let keep = block.shouldKeep(queueIndex: position) ?? false
    let why =
      keep ? "\(line.displayName) uses the \(tile.name)." : "\(line.displayName) doesn't use the \(tile.name)."
    return .keepPass(line: line, rack: block.tiles, tile: tile, keep: keep, why: why)
  }
}

/// The Speed Round clock and score: +1 s for a right answer, -2 s for a wrong one; or 30 untimed
/// questions with "No timer" on.
public struct SpeedClock: Equatable, Sendable {
  public static let startSeconds = 60.0
  public static let bonusSeconds = 1.0
  public static let penaltySeconds = 2.0
  public static let untimedQuestions = 30

  public var timed: Bool
  public var remaining: Double
  public private(set) var right = 0
  public private(set) var wrong = 0
  public private(set) var run = 0
  public private(set) var bestRun = 0

  public init(timed: Bool = true) {
    self.timed = timed
    remaining = Self.startSeconds
  }

  public var answered: Int { right + wrong }

  public var isOver: Bool { timed ? remaining <= 0 : answered >= Self.untimedQuestions }

  public mutating func answer(correct: Bool) {
    if correct {
      right += 1
      run += 1
      bestRun = max(bestRun, run)
      if timed { remaining += Self.bonusSeconds }
    } else {
      wrong += 1
      run = 0
      if timed { remaining = max(0, remaining - Self.penaltySeconds) }
    }
  }

  public mutating func tick(_ seconds: Double) {
    guard timed else { return }
    remaining = max(0, remaining - seconds)
  }
}
