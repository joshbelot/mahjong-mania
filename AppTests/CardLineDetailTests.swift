import MahjongCore
import Testing

@testable import MahjongMania

private func practiceLine(_ name: String) -> CardLine {
  guard let line = PracticeCard.card.lines.first(where: { $0.name == name }) else {
    preconditionFailure("Practice Card has no line named \(name)")
  }
  return line
}

struct CardLineDetailTests {
  @Test func defaultSuitsAreDotsCracksBams() throws {
    let model = LineDetailModel(line: practiceLine("Year Kongs"))
    let target = try #require(model.current)
    #expect(target.binding.x == .dots)
    #expect(target.binding.y == .cracks)
    #expect(model.k == 0)
    #expect(model.availableShifts == [0])
    #expect(model.suitLegend == "A = Dots \u{00B7} B = Cracks")
  }

  @Test func tryOtherSuitsCyclesThroughEveryBindingOnce() throws {
    var model = LineDetailModel(line: practiceLine("Year Kongs"))
    let count = model.candidates.count
    #expect(count > 1)
    #expect(model.canTrySuits)
    var seen = Set<SuitBinding>()
    for _ in 0..<count {
      let target = try #require(model.current)
      seen.insert(target.binding)
      model.nextSuits()
    }
    #expect(seen.count == count)
    #expect(model.current == model.candidates.first)
  }

  @Test func handsWithoutSuitVariablesHaveNothingToCycle() {
    var model = LineDetailModel(line: practiceLine("Four Winds"))
    #expect(model.canTrySuits == false)
    #expect(model.suitLegend.isEmpty)
    model.nextSuits()
    #expect(model.current != nil)
  }

  @Test func shiftLinesCanMoveTheNumbers() throws {
    var model = LineDetailModel(line: practiceLine("Like Sandwich"))
    #expect(model.availableShifts.count > 1)
    #expect(model.shiftStep == 1)
    model.setShift(3)
    #expect(model.k == 3)
    let first = try #require(model.current)
    #expect(first.binding.k == 3)
    #expect(first.groups.contains { $0.tile == .number(4, .dots) })
    model.setShift(100)
    #expect(model.k == model.availableShifts.last)
  }

  @Test func parityShiftStepsByTwo() {
    let parsed = Notation.parseLine("FF 1111/x 11/y 1111/z DD/x ; 25 ; X ; Odd Likes ; shift2")
    guard case .success(let line) = parsed else {
      Issue.record("Line did not parse")
      return
    }
    var model = LineDetailModel(line: line)
    #expect(model.shiftStep == 2)
    #expect(model.availableShifts.allSatisfy { $0 % 2 == 0 })
    model.setShift(3)
    #expect(model.k % 2 == 0)
  }

  @Test func changingShiftReturnsToTheDefaultSuits() throws {
    var model = LineDetailModel(line: practiceLine("Like Sandwich"))
    model.nextSuits()
    model.setShift(2)
    let target = try #require(model.current)
    #expect(LineDetailModel.isDefaultBinding(target.binding))
  }

  @Test func variantsCanBeSelected() throws {
    var model = LineDetailModel(line: practiceLine("Wind Quints"))
    #expect(model.variantIndexes == [0, 1])
    model.selectVariant(1)
    let second = try #require(model.current)
    #expect(second.variantIndex == 1)
    model.selectVariant(7)
    #expect(model.variantIndex == 1)
  }

  @Test func everyPracticeLineHasAnExampleHand() {
    for line in PracticeCard.card.lines {
      let model = LineDetailModel(line: line)
      #expect(model.current != nil, "\(line.displayName) has no drawable hand")
    }
  }

  @Test func lineWinsCountsMatchingSessions() {
    // The detail screen reads this straight from MahjongCore; the lookup key is the line's stable ID.
    let wins = Scoring.lineWins(cardID: PracticeCard.card.id, sessions: [])
    #expect(wins.isEmpty)
  }
}
