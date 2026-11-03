import Foundation

/// Human-reviewable prerequisites for generated path exercises. This metadata does not affect generation.
enum CurriculumConcepts {
  struct Requirement: Hashable {
    let id: String
    let taughtIn: String
  }

  static func requirements(for part: LessonPart) -> Set<Requirement> {
    var result: Set<Requirement> = []
    for type in part.types {
      if type == .tileFact {
        let facts = TileFacts.pool(difficulty: part.difficulty, focus: part.focus)
        result.formUnion(facts.map { Requirement(id: "tileFact.\($0.conceptID)", taughtIn: $0.taughtIn) })
        if part.difficulty >= 3 && part.focus == 0 {
          let facts = TileFacts.houseFacts(RuleSet(id: "coverage", name: "Coverage"))
            + [.blankSet, .blankSwap]
          result.formUnion(facts.map { Requirement(id: "tileFact.\($0.conceptID)", taughtIn: $0.taughtIn) })
        }
      } else {
        let taught: String
        switch type {
        case .tileFact: continue
        case .groupName: taught = "u2l1"
        case .matchesLine: taught = part.focus == ExerciseFocus.exposedConcealed ? "u2l3" : "u2l2"
        case .whichHand: taught = "u2l4"
        case .jokerLegal: taught = "u3l2"
        case .howFar: taught = "u4l1"
        case .neededTile: taught = "u4l3"
        case .pickHand: taught = "u5l1"
        case .passOne: taught = "u6l1"
        case .keepOrPass: taught = "u6l2"
        case .passThree: taught = "u8l1"
        case .callIt: taught = "u9l1"
        }
        result.insert(Requirement(id: "\(type.rawValue).d\(part.difficulty).f\(part.focus)", taughtIn: taught))
      }
    }
    return result
  }

  static func uncovered(_ requirements: Set<Requirement>, taught: Set<String>, current: String) -> Set<Requirement> {
    requirements.filter { $0.taughtIn != "houseRules" && $0.taughtIn != current && !taught.contains($0.taughtIn) }
  }
}
