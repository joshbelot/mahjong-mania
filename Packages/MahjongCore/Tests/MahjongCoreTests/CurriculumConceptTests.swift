import Testing
@testable import MahjongCore

struct CurriculumConceptTests {
  @Test func everyScoredLessonHasEarlierTeachingForAllEnumeratedRequirements() {
    var taught: Set<String> = []
    for unit in Curriculum.units {
      for node in unit.lessons {
        for part in node.parts {
          let requirements = CurriculumConcepts.requirements(for: part)
          #expect(!requirements.isEmpty, "Missing metadata for \(node.id)")
          #expect(CurriculumConcepts.uncovered(requirements, taught: taught, current: node.id).isEmpty,
            "Untaught concept in \(node.id): \(requirements)")
        }
        taught.insert(node.id)
      }
      // Reviews and checkpoints draw from completed lessons; checkpoint selection also draws earlier units.
      for part in Curriculum.hardestParts(of: unit) {
        let requirements = CurriculumConcepts.requirements(for: part)
        #expect(CurriculumConcepts.uncovered(requirements, taught: taught, current: unit.checkpoint.id).isEmpty,
          "Untaught checkpoint concept in unit \(unit.id): \(requirements)")
      }
    }
  }

  @Test func factIdentifiersEnumeratePoolsAndARegressionDetectsAnUntaughtConcept() {
    let facts = TileFacts.pool(difficulty: 2, focus: 0)
    #expect(Set(facts.map(\.conceptID)).count == facts.count)
    let unknown = CurriculumConcepts.Requirement(id: "future.untaught", taughtIn: "futureLesson")
    #expect(CurriculumConcepts.uncovered([unknown], taught: ["u1l1"], current: "u1l2") == [unknown])
    for type in ExerciseType.allCases where type != .tileFact {
      for difficulty in 1...3 {
        #expect(!CurriculumConcepts.requirements(for: LessonPart([type], difficulty)).isEmpty)
      }
    }
  }
}
