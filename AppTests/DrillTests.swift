import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

struct PickAHandDrillTests {
  private let analyzer = Analyzer(card: PracticeCard.card)

  @Test func dealsAreDeterministicBySeed() {
    let a = PickAHandDrill(seed: 42)
    let b = PickAHandDrill(seed: 42)
    #expect(a == b)
    #expect(a.hand.count == 13)
    #expect(a.hand == a.hand.sortedForDisplay())
    #expect(PickAHandDrill(seed: 1).hand != PickAHandDrill(seed: 2).hand)
  }

  @Test func handsComeFromTheSeededWall() {
    let dealt = Wall.deal(seed: 7).hand.sortedForDisplay()
    #expect(PickAHandDrill(seed: 7).hand == dealt)
  }

  @Test func revealsTheTopThreeInOrder() throws {
    for seed in UInt64(1)...20 {
      let drill = PickAHandDrill(seed: seed)
      let results = analyzer.analyze(PlayerView(rack: drill.hand))
      let first = try #require(results.first)
      let outcome = try #require(drill.outcome(pickedLineID: first.line.id, analyzer: analyzer))
      #expect(outcome.top.count == 3)
      #expect(outcome.top.map(\.distance) == outcome.top.map(\.distance).sorted())
      #expect(outcome.top.first?.id == first.line.id)
      #expect(outcome.isCorrect)
      #expect(outcome.explanation.contains(first.line.displayName))
    }
  }

  @Test func aFarAwayLineIsWrongUnlessItTiesTheThird() throws {
    for seed in UInt64(1)...20 {
      let drill = PickAHandDrill(seed: seed)
      let results = analyzer.analyze(PlayerView(rack: drill.hand))
      let last = try #require(results.last)
      let outcome = try #require(drill.outcome(pickedLineID: last.line.id, analyzer: analyzer))
      let third = try #require(outcome.top.last)
      let inTop = outcome.top.contains { $0.id == last.line.id }
      let expected = last.best.possible && (inTop || last.best.distance <= third.distance)
      #expect(outcome.isCorrect == expected)
      #expect(outcome.picked.id == last.line.id)
      #expect(!outcome.explanation.isEmpty)
    }
  }

  @Test func someDealsHaveAWrongAnswer() throws {
    var wrong = 0
    for seed in UInt64(1)...20 {
      let drill = PickAHandDrill(seed: seed)
      let last = try #require(analyzer.analyze(PlayerView(rack: drill.hand)).last)
      if let outcome = drill.outcome(pickedLineID: last.line.id, analyzer: analyzer), !outcome.isCorrect {
        wrong += 1
      }
    }
    #expect(wrong > 0)
  }

  @Test func sameSeedGivesSameOutcome() throws {
    let line = try #require(PracticeCard.card.lines.first)
    let a = PickAHandDrill(seed: 99).outcome(pickedLineID: line.id, analyzer: analyzer)
    let b = PickAHandDrill(seed: 99).outcome(pickedLineID: line.id, analyzer: analyzer)
    #expect(a != nil)
    #expect(a == b)
  }

  @Test func unknownLineGivesNoOutcome() {
    #expect(PickAHandDrill(seed: 5).outcome(pickedLineID: "nope", analyzer: analyzer) == nil)
  }

  @Test func streakGrowsOnRightAndResetsOnWrong() {
    #expect(PickAHandDrill.updatedStreak(0, correct: true) == 1)
    #expect(PickAHandDrill.updatedStreak(4, correct: true) == 5)
    #expect(PickAHandDrill.updatedStreak(4, correct: false) == 0)
  }
}

struct CharlestonDrillTests {
  private let analyzer = Analyzer(card: PracticeCard.card)

  private func indices(of tiles: [Tile], in hand: [Tile]) -> [Int] {
    var used = Set<Int>()
    var result: [Int] = []
    for tile in tiles {
      if let index = hand.indices.first(where: { hand[$0] == tile && !used.contains($0) }) {
        used.insert(index)
        result.append(index)
      }
    }
    return result
  }

  @Test func dealsAreDeterministicBySeed() {
    #expect(CharlestonDrill(seed: 42) == CharlestonDrill(seed: 42))
    #expect(CharlestonDrill(seed: 42).hand.count == 13)
    #expect(CharlestonDrill(seed: 42).hand == PickAHandDrill(seed: 42).hand)
  }

  @Test func jokersCannotBeSelected() {
    #expect(!CharlestonDrill.canSelect(.joker))
    #expect(CharlestonDrill.canSelect(.flower))
    // Seed 3 deals exactly one joker; it sorts last.
    let drill = CharlestonDrill(seed: 3)
    #expect(drill.hand.last == .joker)
    #expect(drill.evaluate(selection: [0, 1, 12], analyzer: analyzer) == nil)
  }

  @Test func selectionMustBeThreeDistinctValidPositions() {
    let drill = CharlestonDrill(seed: 1)
    #expect(drill.evaluate(selection: [0, 1], analyzer: analyzer) == nil)
    #expect(drill.evaluate(selection: [0, 1, 2, 3], analyzer: analyzer) == nil)
    #expect(drill.evaluate(selection: [0, 0, 1], analyzer: analyzer) == nil)
    #expect(drill.evaluate(selection: [0, 1, 13], analyzer: analyzer) == nil)
    #expect(drill.evaluate(selection: [-1, 1, 2], analyzer: analyzer) == nil)
    #expect(drill.evaluate(selection: [0, 1, 2], analyzer: analyzer) != nil)
  }

  @Test func theEnginesOwnPassesScoreFullMarks() throws {
    for seed in UInt64(1)...20 {
      let drill = CharlestonDrill(seed: seed)
      let advice = analyzer.suggestPasses(PlayerView(rack: drill.hand))
      let picks = indices(of: advice.passes.map(\.tile), in: drill.hand)
      #expect(picks.count == 3)
      let outcome = try #require(drill.evaluate(selection: picks, analyzer: analyzer))
      #expect(outcome.score == 3)
      #expect(outcome.isPerfect)
      #expect(outcome.engine.map(\.tile) == advice.passes.map(\.tile))
      #expect(outcome.engine.map(\.reason) == advice.passes.map(\.reason))
      #expect(outcome.chosen.count == 3)
    }
  }

  @Test func theMostUsefulTilesScoreNoBetterThanTheEngine() throws {
    for seed in UInt64(1)...20 {
      let drill = CharlestonDrill(seed: seed)
      let top = WeightedTopLines(results: analyzer.analyze(PlayerView(rack: drill.hand)))
      let ranked = drill.hand.indices
        .filter { CharlestonDrill.canSelect(drill.hand[$0]) }
        .sorted { top.utility(of: drill.hand[$0], instance: 0) > top.utility(of: drill.hand[$1], instance: 0) }
      let worst = Array(ranked.prefix(3))
      let outcome = try #require(drill.evaluate(selection: worst, analyzer: analyzer))
      #expect((0...3).contains(outcome.score))
      let advice = analyzer.suggestPasses(PlayerView(rack: drill.hand))
      let best = try #require(
        drill.evaluate(selection: indices(of: advice.passes.map(\.tile), in: drill.hand), analyzer: analyzer))
      #expect(outcome.score <= best.score)
      #expect(!outcome.explanation.isEmpty)
    }
  }

  @Test func sameSeedAndSelectionGiveTheSameOutcome() {
    let drill = CharlestonDrill(seed: 11)
    let a = drill.evaluate(selection: [0, 3, 6], analyzer: analyzer)
    let b = CharlestonDrill(seed: 11).evaluate(selection: [0, 3, 6], analyzer: analyzer)
    #expect(a != nil)
    #expect(a == b)
  }

  @Test func streakNeedsFullMarks() {
    #expect(CharlestonDrill.updatedStreak(2, score: 3) == 3)
    #expect(CharlestonDrill.updatedStreak(2, score: 2) == 0)
    #expect(CharlestonDrill.updatedStreak(0, score: 0) == 0)
  }
}

@MainActor
struct TipCenterTests {
  @Test func neverRepeatsATipAcrossScreens() {
    let center = TipCenter(seed: 5)
    var seen = Set<String>()
    for index in 0..<Tips.all.count {
      let tip = center.tip(for: "screen\(index)")
      #expect(tip != nil)
      if let tip { #expect(seen.insert(tip.id).inserted) }
    }
    #expect(seen.count == Tips.all.count)
    #expect(center.tip(for: "one-too-many") == nil)
  }

  @Test func aScreenKeepsItsTipUntilDismissed() {
    let center = TipCenter(seed: 9)
    let first = center.tip(for: "learn.home")
    #expect(first != nil)
    #expect(center.tip(for: "learn.home") == first)
    center.dismiss(screen: "learn.home")
    #expect(center.tip(for: "learn.home") == nil)
    let other = center.tip(for: "other")
    #expect(other != nil)
    #expect(other != first)
  }

  @Test func sameSeedGivesSameFirstTip() {
    #expect(TipCenter(seed: 3).tip(for: "a") == TipCenter(seed: 3).tip(for: "a"))
  }
}

struct DrillSeedTests {
  @Test func randomSeedsAreSmallAndPositive() {
    for _ in 0..<50 {
      let seed = DrillSeed.random()
      #expect(seed >= 1 && seed <= 999_999)
    }
  }
}
