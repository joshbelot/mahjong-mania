import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

/// The Practice exercise engine (MahjongCore) grades Pick-a-Hand and Charleston Pass exactly like the
/// v1.0 drills it replaces (SPEC §18.12, Phase 21).
struct ExerciseCompatibilityTests {
  private let analyzer = Analyzer.cached(for: PracticeCard.card)

  @Test func pickHandGradesLikeTheOldDrill() throws {
    for seed in UInt64(1)...25 {
      let drill = PickAHandDrill(seed: seed)
      let exercise = Exercises.make(
        ExerciseID(type: .pickHand, seed: seed, difficulty: 3), card: PracticeCard.card)
      #expect(exercise.tiles == drill.hand)
      for (index, choice) in exercise.choices.enumerated() {
        guard case .line(let line) = choice else { continue }
        let old = try #require(drill.outcome(pickedLineID: line.id, analyzer: analyzer))
        let new = Exercises.grade(exercise, answer: .choice(index), card: PracticeCard.card)
        #expect(new.correct == old.isCorrect, "seed \(seed) \(line.displayName)")
        #expect(new.explanation == old.explanation)
      }
    }
  }

  @Test func passThreeGradesLikeTheOldDrill() throws {
    var compared = 0
    for seed in UInt64(1)...60 {
      let exercise = Exercises.make(
        ExerciseID(type: .passThree, seed: seed, difficulty: 3), card: PracticeCard.card)
      // The hard deal is the v1 deal only when the first candidate passed the filter; compare on its own tiles.
      let hand = exercise.tiles
      let old = CharlestonDrill(seed: seed)
      if hand == old.hand {
        compared += 1
        for start in 0..<6 {
          let selection = [start, start + 3, start + 6]
          guard selection.allSatisfy({ CharlestonDrill.canSelect(hand[$0]) }) else { continue }
          let oldOutcome = try #require(old.evaluate(selection: selection, analyzer: analyzer))
          let new = Exercises.grade(exercise, answer: .tiles(selection), card: PracticeCard.card)
          #expect(new.score == oldOutcome.score, "seed \(seed)")
        }
      }
    }
    #expect(compared >= 5)
  }
}
