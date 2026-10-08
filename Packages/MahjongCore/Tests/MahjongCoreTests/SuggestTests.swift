import Foundation
import Testing

@testable import MahjongCore

private let practice = Analyzer(card: PracticeCard.card)

private func line(_ name: String) -> CardLine {
  PracticeCard.card.lines.first { $0.name == name }!
}

private func target(_ name: String, x: Suit? = nil, y: Suit? = nil, z: Suit? = nil, k: Int = 0) -> Target {
  Engine.expand(line(name)).first {
    (x == nil || $0.binding.x == x) && (y == nil || $0.binding.y == y) && (z == nil || $0.binding.z == z)
      && $0.binding.k == k
  }!
}

private func customCard(_ text: String) -> Card {
  let parsed = Notation.parseCardFile(text)
  precondition(parsed.errors.isEmpty, "\(parsed.errors)")
  return Notation.makeCard(from: parsed, id: "custom", createdAt: Date(timeIntervalSince1970: 0))
}

private func removing(_ tiles: [Tile], from rack: [Tile]) -> [Tile] {
  var rack = rack
  for tile in tiles { rack.removeOne(tile) }
  return rack
}

struct PassSuggestionTests {
  @Test func neverSuggestsJokersAndReturnsExactlyCount() {
    for seed in UInt64(1)...40 {
      var hand = Wall.deal(seed: seed).hand
      hand[0] = .joker
      hand[1] = .joker
      let advice = practice.suggestPasses(PlayerView(rack: hand), count: 3)
      #expect(advice.passes.count == 3)
      #expect(advice.passes.allSatisfy { $0.tile != .joker })
      // Every suggested tile really is in the rack, with no more copies than held.
      let held = hand.counts
      for (tile, n) in advice.passes.map(\.tile).counts { #expect(n <= (held[tile] ?? 0)) }
    }
  }

  @Test func honoursCountParameter() {
    let hand = Wall.deal(seed: 3).hand
    #expect(practice.suggestPasses(PlayerView(rack: hand), count: 1).passes.count == 1)
    #expect(practice.suggestPasses(PlayerView(rack: hand), count: 0).passes.isEmpty)
    #expect(practice.suggestPasses(PlayerView(rack: [.number(1, .dots)]), count: 3).passes.count == 1)
  }

  @Test func strayTilesAreExplained() {
    let evenClimb = target("Even Climb", x: .bams)
    let rack = evenClimb.tiles.filter { $0 != .number(8, .bams) } + [.wind(.north), .wind(.south), .dragon(.green)]
    let advice = practice.suggestPasses(PlayerView(rack: Array(rack.prefix(13))), count: 3)
    #expect(advice.passes.count == 3)
    let reasons = advice.passes.map(\.reason)
    #expect(
      reasons.allSatisfy {
        $0 == "Not used by your top hands" || $0 == "No hand on this card uses it" || $0.hasPrefix("Only helps ")
      })
  }

  @Test func tileNoHandUsesGetsTheSpecificReason() {
    let card = customCard(
      """
      NNNN EEE WWW SSSS ; 25 ; X ; Winds
      """)
    let analyzer = Analyzer(card: card)
    let rack: [Tile] = [
      .wind(.north), .wind(.north), .wind(.north), .wind(.east), .wind(.east), .wind(.east), .wind(.west),
      .wind(.west), .wind(.west), .wind(.south), .wind(.south), .wind(.south), .number(5, .cracks),
    ]
    let advice = analyzer.suggestPasses(PlayerView(rack: rack))
    #expect(advice.passes.first?.tile == .number(5, .cracks))
    #expect(advice.passes.first?.reason == "No hand on this card uses it")
    #expect(analyzer.coverage(of: .number(5, .cracks)) == 0)
    #expect(analyzer.coverage(of: .wind(.north)) == 1)
  }

  @Test func onlyOneOfTwoCopiesIsSuggestedWhenOnlyOneIsUsed() {
    let card = customCard(
      """
      7/b 11/c NNNN EEEE FFF ; 25 ; X ; Single Seven
      """)
    let analyzer = Analyzer(card: card)
    let rack: [Tile] =
      [.number(7, .bams), .number(7, .bams), .number(1, .cracks), .number(1, .cracks)]
      + Array(repeating: .wind(.north), count: 4) + Array(repeating: .wind(.east), count: 4)
      + [.flower]
    #expect(rack.count == 13)
    let advice = analyzer.suggestPasses(PlayerView(rack: rack), count: 3)
    let sevens = advice.passes.filter { $0.tile == .number(7, .bams) }
    #expect(sevens.count == 1)
    #expect(sevens.first?.reason == "Not used by your top hands")
    #expect(advice.passes.count == 3)
  }

  @Test func usedTilesGetTheOnlyHelpsReason() {
    let card = customCard(
      """
      NNNN EEE WWW SSSS ; 25 ; X ; Winds
      NN EE WW SS 11/x 11/y 11/z ; 50 ; C ; Pairs
      """)
    let analyzer = Analyzer(card: card)
    let rack: [Tile] = [
      .wind(.north), .wind(.north), .wind(.north), .wind(.east), .wind(.east), .wind(.east), .wind(.west),
      .wind(.west), .wind(.west), .wind(.south), .wind(.south), .wind(.south), .number(5, .cracks),
    ]
    let advice = analyzer.suggestPasses(PlayerView(rack: rack), count: 13)
    #expect(advice.passes.count == 13)
    #expect(advice.passes.contains { $0.reason == "Only helps Winds (4 away)" })
  }

  @Test func focusNamesTheStrongestSections() {
    let evenClimb = target("Even Climb", x: .bams)
    let rack = Array(evenClimb.tiles.prefix(13))
    let advice = practice.suggestPasses(PlayerView(rack: rack))
    #expect(!advice.focus.isEmpty)
    #expect(advice.focus.count <= 3)
    #expect(advice.focus.first?.section == "2468")
    #expect(advice.focusSections.first == "2468")
    #expect(advice.focus.first?.lines.contains("Even Climb") == true)
  }
}

struct DiscardSuggestionTests {
  @Test func oneAwayHandKeepsDistanceOneAfterDiscardingTheStray() {
    let climb = target("Even Climb", x: .bams)
    var rack = climb.tiles
    rack.removeOne(.number(2, .bams))
    rack.append(.wind(.north))
    #expect(rack.count == 14)
    let suggestions = practice.suggestDiscards(PlayerView(rack: rack))
    #expect(suggestions.count == 3)
    #expect(suggestions.first?.tile == .wind(.north))
    #expect(suggestions.first?.resultingDistance == 1)
    #expect(suggestions.first?.reason == "Keeps you 1 away on Even Climb")
    #expect(suggestions.map(\.resultingDistance) == suggestions.map(\.resultingDistance).sorted())
  }

  @Test func neverSuggestsAJoker() {
    for seed in UInt64(1)...20 {
      var hand = Wall.deal(seed: seed, count: 14).hand
      hand[0] = .joker
      let suggestions = practice.suggestDiscards(PlayerView(rack: hand))
      #expect(!suggestions.isEmpty)
      #expect(suggestions.allSatisfy { $0.tile != .joker })
    }
  }

  @Test func dangerBreaksTiesAndIsAnnotated() {
    let card = customCard(
      """
      NNNN EEE WWW SSSS ; 25 ; X ; Winds
      """)
    let analyzer = Analyzer(card: card)
    let rack: [Tile] =
      Array(repeating: .wind(.north), count: 4) + Array(repeating: .wind(.east), count: 3)
      + Array(repeating: .wind(.west), count: 3) + [.wind(.south), .wind(.south), .number(5, .cracks), .number(6, .cracks)]
    #expect(rack.count == 14)
    let plain = analyzer.suggestDiscards(PlayerView(rack: rack))
    #expect(plain.first?.tile == .number(5, .cracks))
    let risky = analyzer.suggestDiscards(PlayerView(rack: rack), danger: [.number(5, .cracks): 0.9])
    #expect(risky.first?.tile == .number(6, .cracks))
    let annotated = analyzer.suggestDiscards(PlayerView(rack: rack), danger: [.number(5, .cracks): 0.9, .number(6, .cracks): 0.9])
    #expect(annotated.first?.reason.hasSuffix(" · risky: an opponent may need it") == true)
  }
}

struct CallCheckTests {
  @Test func completingThePairOfAConcealedHandIsMahjong() {
    let pairs = target("Even Pairs", x: .bams, y: .dots)
    var rack = pairs.tiles
    rack.removeOne(.number(4, .bams))
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .number(4, .bams))
    let mahjongs = verdicts.compactMap { verdict -> CardLine? in
      if case .mahjong(let line) = verdict { return line }
      return nil
    }
    #expect(mahjongs.map(\.name).contains("Even Pairs"))
    #expect(mahjongs.first { $0.name == "Even Pairs" }?.concealed == true)
    if case .mahjong = verdicts.first {
    } else {
      Issue.record("Mahjong verdicts must come first")
    }
  }

  @Test func exposeVerdictReportsTheNewDistance() {
    let climb = target("Even Climb", x: .bams)
    var rack = climb.tiles
    rack.removeOne(.number(6, .bams))
    rack.removeOne(.number(8, .bams))
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .number(6, .bams))
    let expose = verdicts.compactMap { verdict -> (CardLine, Int, Int)? in
      if case .expose(let line, let size, let distance) = verdict { return (line, size, distance) }
      return nil
    }.first { $0.0.name == "Even Climb" }
    #expect(expose?.1 == 3)
    #expect(expose?.2 == 1)
  }

  @Test func jokersCanHelpMakeTheExposure() {
    let climb = target("Even Climb", x: .bams)
    var rack = climb.tiles
    rack.removeOne(.number(6, .bams))
    rack.removeOne(.number(6, .bams))
    rack.removeOne(.number(8, .bams))
    rack.append(.joker)
    // Holds one 6 Bam and a joker; calling a 6 Bam makes a pung of 6s.
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .number(6, .bams))
    let found = verdicts.contains { verdict in
      if case .expose(let line, let size, _) = verdict { return line.name == "Even Climb" && size == 3 }
      return false
    }
    #expect(found)
  }

  @Test func noExposeVerdictForAPairTile() {
    let climb = target("Odd Climb", x: .dots)
    var rack = climb.tiles
    rack.removeOne(.number(1, .dots))
    rack.removeOne(.number(3, .dots))
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .number(1, .dots))
    let names = verdicts.map { verdict -> String? in
      switch verdict {
      case .mahjong(let line): return line.name
      case .expose(let line, _, _): return line.name
      }
    }
    #expect(!names.contains("Odd Climb"))
  }

  @Test func noExposeVerdictForConcealedLines() {
    let compass = target("Compass Dragons")
    var rack = compass.tiles
    rack.removeOne(.flower)
    rack.removeOne(.wind(.north))
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .flower)
    for verdict in verdicts {
      if case .expose(let line, _, _) = verdict { #expect(line.name != "Compass Dragons") }
    }
  }

  @Test func uselessTileGivesNoVerdict() {
    let climb = target("Even Climb", x: .bams)
    let verdicts = practice.checkCall(PlayerView(rack: climb.tiles), tile: .wind(.north))
    let names = verdicts.compactMap { verdict -> String? in
      if case .expose(let line, _, _) = verdict { return line.name }
      return nil
    }
    #expect(!names.contains("Even Climb"))
  }

  @Test func versionsAreSortedMahjongFirstThenByDistance() {
    let climb = target("Even Climb", x: .bams)
    var rack = climb.tiles
    rack.removeOne(.number(6, .bams))
    let verdicts = practice.checkCall(PlayerView(rack: rack), tile: .number(6, .bams))
    var sawNonMahjong = false
    var lastDistance = 0
    for verdict in verdicts {
      switch verdict {
      case .mahjong: #expect(!sawNonMahjong)
      case .expose(_, _, let distance):
        sawNonMahjong = true
        #expect(distance >= lastDistance)
        lastDistance = distance
      }
    }
  }
}

struct ScoutTests {
  private let analyzer = Analyzer(
    card: customCard(
      """
      666/x 4444/x 9999/x FFF ; 25 ; X ; L1
      666/x 4444/x 8888/x 111/y ; 25 ; X ; L2
      666/x 5555/x 7777/x 333/y ; 25 ; C ; L3
      """))

  private let sixes = Exposure(tiles: [.number(6, .bams), .number(6, .bams), .number(6, .bams)])

  @Test func noExposuresMeansAnEmptyReport() {
    let report = analyzer.scout(opponents: [OpponentInput(label: "Right", exposures: [])])
    #expect(report.perOpponent.isEmpty)
    #expect(report.danger.isEmpty)
    #expect(report.safe.isEmpty)
    #expect(analyzer.scout(opponents: []).perOpponent.isEmpty)
  }

  @Test func consistentLinesExcludeConcealedOnes() {
    let report = analyzer.scout(opponents: [OpponentInput(label: "Right", exposures: [sixes])])
    #expect(report.perOpponent.count == 1)
    #expect(report.perOpponent[0].label == "Right")
    #expect(report.perOpponent[0].lines.map(\.name) == ["L1", "L2"])
  }

  @Test func dangerIsNormalisedAndOrdered() throws {
    let report = analyzer.scout(opponents: [OpponentInput(label: "Right", exposures: [sixes])])
    // Consistent targets: L1(x=Bams), L2(x=Bams,y=Cracks), L2(x=Bams,y=Dots).
    let fours = try #require(report.danger[.number(4, .bams)])
    let eights = try #require(report.danger[.number(8, .bams)])
    let nines = try #require(report.danger[.number(9, .bams)])
    #expect(abs(fours - 1.0) < 1e-9)
    #expect(abs(eights - 2.0 / 3.0) < 1e-9)
    #expect(abs(nines - 1.0 / 3.0) < 1e-9)
    #expect(abs((report.danger[.flower] ?? 0) - 1.0 / 3.0) < 1e-9)
    #expect(fours > eights && eights > nines)
    #expect(report.danger.values.allSatisfy { $0 > 0 && $0 <= 1 })
  }

  @Test func safeTilesHaveNoDangerAndNeverIncludeJokers() {
    let report = analyzer.scout(opponents: [OpponentInput(label: "Right", exposures: [sixes])])
    #expect(!report.safe.contains(.joker))
    #expect(!report.safe.contains(.number(4, .bams)))
    #expect(report.safe.contains(.number(5, .bams)))  // only the excluded concealed line needs it
    #expect(report.safe.contains(.number(6, .bams)))  // already exposed
    #expect(report.safe.allSatisfy { (report.danger[$0] ?? 0) == 0 })
  }

  @Test func inconsistentExposureLeavesNoLines() {
    let kong = Exposure(tiles: [.wind(.north), .wind(.north), .wind(.north), .wind(.north)])
    let report = analyzer.scout(opponents: [OpponentInput(label: "Across", exposures: [kong])])
    #expect(report.perOpponent.count == 1)
    #expect(report.perOpponent[0].lines.isEmpty)
    #expect(report.danger.isEmpty)
  }

  @Test func maxAcrossOpponents() {
    let report = analyzer.scout(
      opponents: [
        OpponentInput(label: "Right", exposures: [sixes]),
        OpponentInput(label: "Left", exposures: []),
      ])
    #expect(report.perOpponent.map(\.label) == ["Right"])
  }

  @Test func fullyVisibleTilesAreNotDangerous() {
    let report = analyzer.scout(
      opponents: [OpponentInput(label: "Right", exposures: [sixes])], seen: [.number(4, .bams): 4])
    #expect((report.danger[.number(4, .bams)] ?? 0) == 0)
    #expect(report.safe.contains(.number(4, .bams)))
  }
}
