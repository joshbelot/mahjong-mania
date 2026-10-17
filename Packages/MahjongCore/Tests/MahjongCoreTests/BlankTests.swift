import Foundation
import Testing

@testable import MahjongCore

private let analyzer = Analyzer(card: PracticeCard.card)

/// Even Climb in Bams, a 6 Bam and an 8 Bam short.
private let climb: [Tile] = [2, 2, 2, 4, 4, 4, 4, 6, 6, 8, 8, 8].map { .number($0, .bams) }

struct BlankTileTests {
  @Test func codeNameAndCopies() {
    #expect(Tile(code: "BL") == .blank)
    #expect(Tile.blank.code == "BL")
    #expect(Tile.blank.name == "Blank")
    #expect(Tile.blank.copies == Tile.maxBlanks)
    #expect(Tile(code: "B") == nil)
    #expect(Tile(code: "BX") == nil)
  }

  @Test func theStandardSetIsUnchanged() {
    #expect(Tile.allCases.count == 36)
    #expect(!Tile.allCases.contains(.blank))
    #expect(Tile.allWithBlank.count == 37)
    #expect(Tile.allWithBlank.last == .blank)
    #expect(Wall.full().count == 152)
    #expect(Tile.blank.sortIndex == 36)
    #expect(Tile.joker < Tile.blank)
  }

  @Test func codableRoundTrip() throws {
    let data = try JSONEncoder().encode([Tile.blank, .joker])
    #expect(String(decoding: data, as: UTF8.self) == "[\"BL\",\"J\"]")
    #expect(try JSONDecoder().decode([Tile].self, from: data) == [.blank, .joker])
  }

  @Test func wallWithBlanks() {
    #expect(Wall.full(blanks: 4).count == 156)
    #expect(Wall.full(blanks: 4).filter { $0 == .blank }.count == 4)
    #expect(Wall.full(blanks: 99).filter { $0 == .blank }.count == Tile.maxBlanks)
    #expect(Wall.full(blanks: -2).count == 152)
    let dealt = Wall.deal(seed: 7, count: 13, blanks: 6)
    #expect(dealt.hand.count == 13)
    #expect(dealt.hand.count + dealt.rest.count == 158)
    #expect(Wall.deal(seed: 7, count: 13).hand == Wall.deal(seed: 7, count: 13, blanks: 0).hand)
  }
}

struct BlankNotationTests {
  @Test func aBlankCannotBePartOfAHand() {
    for text in ["BL FF 2222/x 4444/y ; 25 ; X", "FF 2222/x BLBL ; 25 ; X"] {
      guard case .failure(let list) = Notation.parseLine(text) else {
        Issue.record("\(text) should not parse")
        continue
      }
      #expect(list.errors.contains { $0.message == "Blanks can't be part of a hand" })
      #expect(!list.errors.contains { $0.message.contains("isn't a tile") })
    }
  }
}

struct BlankEngineTests {
  @Test func aBlankNeverFillsAGroup() {
    let without = analyzer.analyze(PlayerView(rack: climb))
    let with = analyzer.analyze(PlayerView(rack: climb + [.blank]))
    #expect(with.first?.line.name == without.first?.line.name)
    #expect(with.first?.best.distance == without.first?.best.distance)
    #expect(with.first?.best.unusedRack.contains(.blank) == true)
    #expect(with.first?.best.usedRack[.blank] == nil)
  }

  @Test func blanksCountTowardsTheTilesInAHand() {
    let view = PlayerView(rack: climb + [.blank, .blank])
    #expect(view.rack.count == 14)
    #expect(analyzer.analyze(view).first?.best.distance == 2)
  }

  /// Compass Dragons needs a North; with all four seen it is dead, unless a blank could get one back.
  @Test func aBlankKeepsALineAliveWhileTheTileIsInTheDiscards() {
    let seen: TileCounts = [.wind(.north): 4]
    func compass(_ rack: [Tile], _ policy: BlankPolicy?) -> LineResult? {
      analyzer.analyze(PlayerView(rack: rack), seen: seen, blanks: policy).first { $0.line.name == "Compass Dragons" }
    }
    #expect(compass([], nil)?.best.possible == false)
    #expect(compass([.blank], nil)?.best.possible == false, "without the rule a blank changes nothing")
    #expect(compass([], BlankPolicy())?.best.possible == false, "no blank in the rack")
    #expect(compass([.blank], BlankPolicy())?.best.possible == true)
    #expect(compass([.blank], BlankPolicy())?.best.impossibleReason == nil)
    // A tile that was never seen is not helped by a blank.
    let other = analyzer.analyze(PlayerView(rack: [.blank]), seen: [.wind(.north): 4, .wind(.south): 4], blanks: BlankPolicy())
    #expect(other.first { $0.line.name == "Compass Dragons" }?.best.possible == true)
  }

  @Test func evaluateAcceptsThePolicy() {
    let target = Target(
      lineID: "t", variantIndex: 0, binding: SuitBinding(),
      groups: [TargetGroup(tile: .wind(.north), count: 2, jokerOK: false, groupIndex: 0)])
    let view = PlayerView(rack: [.blank])
    let seen: TileCounts = [.wind(.north): 4]
    let line = PracticeCard.card.lines[0]
    let live = Engine.liveCounts(view, seen: seen)
    #expect(Engine.evaluate(target, line: line, view: view, live: live).possible == false)
    #expect(Engine.evaluate(target, line: line, view: view, live: live, seen: seen, blanks: BlankPolicy()).possible)
  }
}

struct BlankSuggestionTests {
  private var rack14: [Tile] { climb + [.blank, .blank] }

  @Test func neverSuggestsAPassOrDiscardOfABlank() {
    let view = PlayerView(rack: rack14)
    #expect(!analyzer.suggestPasses(view).passes.map(\.tile).contains(.blank))
    #expect(!analyzer.suggestDiscards(view).map(\.tile).contains(.blank))
    // Even when the blanks are the only things that help nothing.
    let allBlankish = PlayerView(rack: [.blank, .blank, .blank, .wind(.north), .wind(.east), .flower])
    #expect(!analyzer.suggestPasses(allBlankish).passes.map(\.tile).contains(.blank))
  }

  @Test func swapAdviceNeedsABlankAndASeenTileThatHelps() {
    let view = PlayerView(rack: climb + [.blank])
    #expect(analyzer.suggestBlankSwaps(PlayerView(rack: climb), seen: [.number(6, .bams): 1]).isEmpty)
    #expect(analyzer.suggestBlankSwaps(view, seen: [:]).isEmpty)
    let swaps = analyzer.suggestBlankSwaps(view, seen: [.number(6, .bams): 1, .number(5, .dots): 2])
    #expect(swaps.map(\.tile) == [.number(6, .bams)])
    #expect(swaps.first?.newDistance == 1)
    #expect(swaps.first?.currentDistance == 2)
    #expect(swaps.first?.lineName.isEmpty == false)
    #expect(swaps.first?.text.hasPrefix("Swap a blank for the 6 Bam (if it's still in the discards): 1 away on ") == true)
  }

  @Test func swapAdviceShowsAtMostThree() {
    let view = PlayerView(rack: climb + [.blank])
    let seen: TileCounts = [
      .number(6, .bams): 1, .number(8, .bams): 1, .number(4, .bams): 1, .number(2, .bams): 1,
    ]
    let swaps = analyzer.suggestBlankSwaps(view, seen: seen)
    #expect(swaps.count <= 3)
    #expect(swaps.allSatisfy { $0.newDistance < $0.currentDistance })
  }

  @Test func jokersCanBeSwappedForOnlyWhenTheRuleAllowsIt() {
    let view = PlayerView(rack: climb + [.blank])
    let seen: TileCounts = [.joker: 2]
    #expect(analyzer.suggestBlankSwaps(view, seen: seen, policy: BlankPolicy(swapForJoker: false)).isEmpty)
    let allowed = analyzer.suggestBlankSwaps(view, seen: seen, policy: BlankPolicy(swapForJoker: true))
    #expect(allowed.map(\.tile) == [.joker])
    #expect(allowed.first?.newDistance == 1)
  }
}
