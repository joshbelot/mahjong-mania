import Foundation

/// A slice of a lesson: which exercise types it mixes, how hard, and what they focus on.
public struct LessonPart: Hashable, Sendable {
  public var types: [ExerciseType]
  public var difficulty: Int
  public var focus: Int

  public init(_ types: [ExerciseType], _ difficulty: Int, focus: Int = 0) {
    self.types = types
    self.difficulty = difficulty
    self.focus = focus
  }
}

public enum NodeKind: String, Codable, Sendable {
  case lesson, review, checkpoint
}

/// One node of the path (SPEC §18.4).
public struct LessonSpec: Hashable, Identifiable, Sendable {
  public var id: String
  public var unit: Int
  public var kind: NodeKind
  public var title: String
  /// A short teaching card shown before the questions.
  public var intro: String
  /// Number of questions (before any re-asked mistakes).
  public var count: Int
  public var parts: [LessonPart]
}

public struct UnitSpec: Hashable, Identifiable, Sendable {
  public var id: Int
  public var title: String
  public var summary: String
  /// Lessons in order, without the review and checkpoint nodes.
  public var lessons: [LessonSpec]
  public var review: LessonSpec?
  public var checkpoint: LessonSpec

  /// All nodes in play order: lessons with the review node in the middle, then the checkpoint.
  public var nodes: [LessonSpec] {
    var result = lessons
    if let review { result.insert(review, at: min(result.count, (lessons.count + 1) / 2)) }
    result.append(checkpoint)
    return result
  }
}

public enum Curriculum {
  public static let reviewCount = 8
  public static let checkpointCount = 10
  public static let checkpointPassMark = 7
  public static let testOutPassMark = 8
  public static let goldPassFraction = 0.9

  public static func unit(_ number: Int) -> UnitSpec? { units.first { $0.id == number } }

  public static let allNodes: [LessonSpec] = units.flatMap(\.nodes)

  public static func node(id: String) -> LessonSpec? { allNodes.first { $0.id == id } }

  /// Lessons only (no review or checkpoint nodes), for star and gold counting.
  public static func lessons(inUnit number: Int) -> [LessonSpec] { unit(number)?.lessons ?? [] }

  // MARK: Building a play

  /// The questions of one play of `node`. `review` are due exercises from the review queue (used by
  /// review nodes); `gold` raises every lesson question by one difficulty.
  public static func exercises(
    for node: LessonSpec, seed: UInt64, gold: Bool = false, review: [ExerciseID] = []
  ) -> [ExerciseID] {
    var rng = SeededRandom(seed: seed ^ 0xC0DE)
    switch node.kind {
    case .lesson:
      return fromParts(node.parts, count: node.count, gold: gold, rng: &rng)

    case .review:
      var result = Array(review.prefix(node.count))
      let fill = node.count - result.count
      if fill > 0 {
        let unitParts = unit(node.unit).map { hardestParts(of: $0) } ?? node.parts
        result += fromParts(unitParts, count: fill, gold: false, rng: &rng)
      }
      return result

    case .checkpoint:
      guard let spec = unit(node.unit) else { return [] }
      let own = fromParts(hardestParts(of: spec), count: node.count >= 10 ? 7 : node.count, gold: false, rng: &rng)
      let earlier = units.filter { $0.id < node.unit }.flatMap { $0.lessons.flatMap(\.parts) }
      var extra: [ExerciseID] = []
      while extra.count < node.count - own.count {
        guard let part = rng.element(of: earlier), let type = rng.element(of: part.types) else { break }
        extra.append(ExerciseID(type: type, seed: rng.next(), difficulty: part.difficulty, focus: 0))
      }
      // No earlier units (Unit 1): all questions come from the unit itself.
      if extra.count < node.count - own.count {
        extra += fromParts(hardestParts(of: spec), count: node.count - own.count - extra.count, gold: false, rng: &rng)
      }
      return rng.shuffled(own + extra)
    }
  }

  /// A unit's types, each at the highest difficulty the unit asks it at (no lesson focus).
  static func hardestParts(of unit: UnitSpec) -> [LessonPart] {
    var order: [ExerciseType] = []
    var hardest: [ExerciseType: Int] = [:]
    for part in unit.lessons.flatMap(\.parts) {
      for type in part.types {
        if hardest[type] == nil { order.append(type) }
        hardest[type] = max(hardest[type] ?? 1, part.difficulty)
      }
    }
    return order.map { LessonPart([$0], hardest[$0] ?? 1) }
  }

  private static func fromParts(
    _ parts: [LessonPart], count: Int, gold: Bool, rng: inout SeededRandom
  ) -> [ExerciseID] {
    guard !parts.isEmpty, count > 0 else { return [] }
    var result: [ExerciseID] = []
    for (index, part) in parts.enumerated() {
      let share = count / parts.count + (index < count % parts.count ? 1 : 0)
      for i in 0..<share {
        let type = part.types[i % part.types.count]
        result.append(
          ExerciseID(
            type: type, seed: rng.next(), difficulty: min(3, part.difficulty + (gold ? 1 : 0)),
            focus: part.focus))
      }
    }
    return result
  }

  /// A fresh question of the same type and difficulty, for "Let's try those again".
  public static func reask(_ id: ExerciseID, seed: UInt64) -> ExerciseID {
    ExerciseID(type: id.type, seed: seed, difficulty: id.difficulty, focus: id.focus)
  }

  /// Which skill group an exercise type trains, for the profile's accuracy bars.
  public enum Skill: String, CaseIterable, Codable, Sendable {
    case tiles, cardReading, jokers, distance, choosing, charleston, calling

    public var title: String {
      switch self {
      case .tiles: return "Tiles"
      case .cardReading: return "Card reading"
      case .jokers: return "Jokers"
      case .distance: return "Distance"
      case .choosing: return "Choosing"
      case .charleston: return "Charleston"
      case .calling: return "Calling"
      }
    }
  }

  public static func skill(of type: ExerciseType) -> Skill {
    switch type {
    case .nameTile, .findTile, .groupName: return .tiles
    case .matchesLine, .whichHand: return .cardReading
    case .jokerLegal: return .jokers
    case .howFar, .neededTile: return .distance
    case .pickHand: return .choosing
    case .passOne, .passThree, .keepOrPass: return .charleston
    case .callIt: return .calling
    }
  }
}
