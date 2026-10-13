import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

/// Guards what one tile tap costs on the main actor: the closest-hands analysis plus the Coach advice
/// for a full rack. Measured 2026-10-13 on an Apple-silicon Mac: Release max 4.4 ms (analysis 0.3 ms,
/// discards 3.5 ms), Debug max 66 ms. The bound is deliberately loose so a slow CI machine does not
/// flake; it only has to catch an accidental order-of-magnitude regression.
@MainActor
struct HelperTimingTests {
  private static let budgetMilliseconds = 250.0

  /// Scout with three exposed pungs per opponent feeds the danger map into the discard advice.
  @Test func scoutedDiscardTime() {
    let analyzer = Analyzer(card: PracticeCard.card)
    func pung(_ code: String) -> Exposure { Exposure(tiles: [Tile(code: code)!, Tile(code: code)!, Tile(code: code)!]) }
    let opponents = [
      OpponentInput(label: "Right", exposures: [pung("2B"), pung("6B")]),
      OpponentInput(label: "Across", exposures: [pung("1D"), pung("N")]),
      OpponentInput(label: "Left", exposures: [pung("9C"), pung("R")]),
    ]
    var scoutTimes: [Double] = []
    var discardTimes: [Double] = []
    for seed in 1...30 {
      let view = PlayerView(rack: Wall.deal(seed: UInt64(seed), count: 11).hand, exposures: [pung("4D")])
      var t = ContinuousClock.now
      let report = analyzer.scout(opponents: opponents, seen: [:])
      scoutTimes.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
      t = ContinuousClock.now
      _ = analyzer.suggestDiscards(view, seen: [:], danger: report.danger)
      discardTimes.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
    }
    #expect(scoutTimes.max()! < Self.budgetMilliseconds)
    #expect(discardTimes.max()! < Self.budgetMilliseconds)
  }

  @Test func fullRackAnalysisTime() {
    let analyzer = Analyzer(card: PracticeCard.card)
    var analyze: [Double] = []
    var passes: [Double] = []
    var discards: [Double] = []
    var scout: [Double] = []
    for seed in 1...60 {
      let dealt = Wall.deal(seed: UInt64(seed), count: 14)
      let view = PlayerView(rack: dealt.hand)
      var t = ContinuousClock.now
      _ = analyzer.analyze(view)
      analyze.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
      t = ContinuousClock.now
      _ = analyzer.suggestPasses(view)
      passes.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
      t = ContinuousClock.now
      _ = analyzer.scout(opponents: HelperDocument.defaultOpponents, seen: [:])
      scout.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
      t = ContinuousClock.now
      _ = analyzer.suggestDiscards(view, seen: [:], danger: [:])
      discards.append(Double((ContinuousClock.now - t).components.attoseconds) / 1e15)
    }
    for values in [analyze, passes, discards, scout] {
      #expect(values.max()! < Self.budgetMilliseconds)
    }
  }
}
