import Testing
@testable import MahjongCore

struct ConcretePracticeFeedbackTests {
  private func example(x: Suit, y: Suit, z: Suit) -> (CardLine, Target, [[Tile]]) {
    let analyzer = Analyzer(card: PracticeCard.card)
    let line = analyzer.card.lines.first { $0.name == "Like Sandwich" }!
    let index = analyzer.lineIndex(of: line)!
    let target = analyzer.targets(at: index).first {
      $0.binding.x == x && $0.binding.y == y && $0.binding.z == z && $0.binding.k == 6
    }!
    let groups = target.groups.map { Array(repeating: $0.tile, count: $0.count) }
    return (line, target, groups)
  }

  @Test func likeNumberExplainsConcreteSuitsAndMatchingDragon() {
    let (line, target, groups) = example(x: .bams, y: .dots, z: .cracks)
    let explanation = ConcretePracticeFeedback.target(target, line: line, groups: groups)
    for term in ["2 × Flower", "4 × 7 Bam", "2 × 7 Dot", "4 × 7 Crack", "2 × Green Dragon", "matches Bams", "all use 7"] {
      #expect(explanation.contains(term), "Missing \(term): \(explanation)")
    }
    #expect(!explanation.contains("1 Bam"))
    let (otherLine, otherTarget, otherGroups) = example(x: .dots, y: .bams, z: .cracks)
    let swapped = ConcretePracticeFeedback.target(otherTarget, line: otherLine, groups: otherGroups)
    #expect(swapped.contains("4 × 7 Dot") && swapped.contains("2 × 7 Bam"))
    #expect(swapped.contains("Soap (White Dragon)") && swapped.contains("matches Dots"))
  }

  @Test func substitutionAndMismatchNameTheActualTiles() {
    let (line, target, original) = example(x: .bams, y: .dots, z: .cracks)
    var joker = original
    joker[1][0] = .joker
    let legal = ConcretePracticeFeedback.target(target, line: line, groups: joker)
    #expect(legal.contains("Joker replaces 7 Bam"))
    var wrong = original
    wrong[1] = Array(repeating: .number(5, .bams), count: 4)
    let reason = ConcretePracticeFeedback.mismatch(shown: wrong, valid: original, target: target, line: line)
    #expect(reason.contains("4 × 5 Bam") && reason.contains("4 × 7 Bam"))
    wrong = original
    wrong[0][0] = .joker
    let illegal = ConcretePracticeFeedback.mismatch(shown: wrong, valid: original, target: target, line: line)
    #expect(illegal.contains("Joker cannot replace") && illegal.contains("pair"))
  }

  @Test func fixedSuitsYearSoapAndShiftedRunsDescribeResolvedTargets() {
    guard case .success(let fixed) = Notation.parseLine("FF 1111/c DDDD/c 2222/b ; 25 ; X ; Fixed") else {
      Issue.record("Could not parse fixed-suit fixture")
      return
    }
    let fixedTarget = Engine.expand(fixed).first!
    let fixedGroups = fixedTarget.groups.map { Array(repeating: $0.tile, count: $0.count) }
    let fixedText = ConcretePracticeFeedback.target(fixedTarget, line: fixed, groups: fixedGroups)
    #expect(fixedText.contains("4 × 1 Crack") && fixedText.contains("Red Dragon matches Cracks"))

    let year = PracticeCard.card.lines.first { $0.name == "Year Kongs" }!
    let yearTarget = Engine.expand(year).first!
    let yearText = ConcretePracticeFeedback.target(yearTarget, line: year,
      groups: yearTarget.groups.map { Array(repeating: $0.tile, count: $0.count) })
    #expect(yearText.contains("Soap (White Dragon)"))

    let run = PracticeCard.card.lines.first { $0.name == "Five Step Run" }!
    let shifted = Engine.expand(run).first { $0.binding.k == 3 }!
    let runText = ConcretePracticeFeedback.target(shifted, line: run,
      groups: shifted.groups.map { Array(repeating: $0.tile, count: $0.count) })
    #expect(runText.contains("4, 5, 6, 7, 8"))

    guard case .success(let parity) = Notation.parseLine("FF 1111/x 3333/y 55/z 77/x ; 25 ; X ; Odd shift ; shift2") else {
      Issue.record("Could not parse parity fixture")
      return
    }
    let parityTarget = Engine.expand(parity).first { $0.binding.k == 2 }!
    let parityText = ConcretePracticeFeedback.target(parityTarget, line: parity,
      groups: parityTarget.groups.map { Array(repeating: $0.tile, count: $0.count) })
    #expect(parityText.contains("keeping odd or even") && parityText.contains("3, 5, 7, 9"))
  }

  @Test func alternativesAndConcealedEligibilityUseTheSelectedVariant() {
    let line = PracticeCard.card.lines.first { $0.name == "Dragons And A Wind" }!
    let target = Engine.expand(line).first { $0.variantIndex == 2 }!
    let groups = target.groups.map { Array(repeating: $0.tile, count: $0.count) }
    let text = ConcretePracticeFeedback.target(target, line: line, groups: groups)
    #expect(text.contains("West") && !text.contains("East"))
    let concealed = PracticeCard.card.lines.first { $0.name == "Like Pairs" }!
    let concealedTarget = Engine.expand(concealed).first!
    let view = PlayerView(rack: [], exposures: [Exposure(tiles: [.flower, .flower, .flower])])
    #expect(!Engine.evaluate(concealedTarget, line: concealed, view: view, live: nil).possible)
  }

  @Test func generatedReadingFeedbackUsesTheShownConcreteTiles() {
    let analyzer = Analyzer(card: PracticeCard.card)
    for type in [ExerciseType.matchesLine, .whichHand] {
      for seed in UInt64(0)..<30 {
        let exercise = Exercises.make(ExerciseID(type: type, seed: seed, difficulty: 1), analyzer: analyzer)
        guard case .choices(let correct, _, let explanation) = exercise.key else {
          Issue.record("Missing answer for \(type) seed \(seed)")
          continue
        }
        #expect(!correct.isEmpty && !explanation.isEmpty)
        if type == .whichHand || correct.contains(0) {
          for tile in Set(exercise.tiles) { #expect(explanation.contains(tile.name)) }
        }
      }
    }
  }
}
