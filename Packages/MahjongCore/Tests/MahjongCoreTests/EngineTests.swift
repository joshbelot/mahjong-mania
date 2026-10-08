import Foundation
import Testing

@testable import MahjongCore

private func line(_ name: String) -> CardLine {
  PracticeCard.card.lines.first { $0.name == name }!
}

private func targets(_ name: String) -> [Target] {
  Engine.expand(line(name))
}

private func pick(_ name: String, x: Suit? = nil, y: Suit? = nil, z: Suit? = nil, k: Int = 0) -> Target {
  let all = targets(name)
  return all.first {
    (x == nil || $0.binding.x == x) && (y == nil || $0.binding.y == y) && (z == nil || $0.binding.z == z)
      && $0.binding.k == k
  }!
}

private func evaluate(_ target: Target, _ name: String, rack: [Tile], exposures: [Exposure] = [], live: TileCounts? = nil)
  -> Evaluation
{
  Engine.evaluate(target, line: line(name), view: PlayerView(rack: rack, exposures: exposures), live: live)
}

struct ExpansionTests {
  @Test func expansionCounts() {
    #expect(targets("Even Climb").count == 3)
    #expect(targets("Three Plus Four").count == 6)
    #expect(targets("Five Step Run").count == 15)
    #expect(targets("Four Winds").count == 1)
    #expect(targets("Dragons And A Wind").count == 4)
    #expect(targets("Like Quints").count == 54)
  }

  @Test func tripleYearDropsDotsAndDedupesSymmetricSuits() {
    // x = Dots would need 5 Soaps and is dropped. For x = Cracks / Bams the two remaining suits can be
    // assigned to y and z in either order, but the hand is identical, so those collapse: 2 targets.
    let all = targets("Triple Year")
    #expect(all.count == 2)
    #expect(all.allSatisfy { $0.binding.x != .dots })
  }

  @Test func distinctSuitsAreEnforced() {
    for target in targets("Three Plus Four") {
      let suits = [target.binding.x, target.binding.y, target.binding.z]
      #expect(Set(suits.compactMap { $0 }).count == 3)
    }
  }

  @Test func matchingDragonResolvesToTheSuitsDragon() {
    let target = pick("Even Dragons", z: .cracks)
    let dragonGroup = target.groups.last
    #expect(dragonGroup?.tile == .dragon(.red))
    #expect(dragonGroup?.count == 4)
    #expect(dragonGroup?.jokerOK == true)
    #expect(pick("Even Dragons", z: .bams).groups.last?.tile == .dragon(.green))
    #expect(pick("Even Dragons", z: .dots).groups.last?.tile == .dragon(.white))
  }

  @Test func shiftMovesAllNumbersTogether() {
    let shifted = pick("Five Step Run", x: .dots, k: 3)
    #expect(shifted.groups.map(\.tile) == [4, 5, 6, 7, 8].map { Tile.number($0, .dots) })
    #expect(targets("Five Step Run").allSatisfy { $0.binding.k >= 0 && $0.binding.k <= 4 })
  }

  @Test func shiftsCanGoNegativeWhenWrittenNumbersAreHigh() {
    let l = Notation.parseLine("FF 5555/x 6666/x 77/x 88/y ; 25 ; X ; Test ; shift")
    guard case .success(let parsed) = l else {
      Issue.record("parse failed")
      return
    }
    let ks = Set(Engine.expand(parsed).map(\.binding.k))
    #expect(ks == Set(-4...1))
  }

  @Test func parityShiftOnlyUsesEvenOffsets() {
    let l = Notation.parseLine("FF 1111/x 2222/x 33/x 44/y ; 25 ; X ; Test ; shift2")
    guard case .success(let parsed) = l else {
      Issue.record("parse failed")
      return
    }
    let ks = Set(Engine.expand(parsed).map(\.binding.k))
    #expect(ks == [0, 2, 4])
  }

  @Test func zeroShiftComesFirst() {
    #expect(targets("Five Step Run").first?.binding.k == 0)
  }

  @Test func needsSplitPlainAndJokerable() {
    let target = pick("Odd Climb", x: .dots)
    // 11/x 333/x 5555/x 777/x 99/x
    #expect(target.plainNeed == [.number(1, .dots): 2, .number(9, .dots): 2])
    #expect(target.jokerNeed == [.number(3, .dots): 3, .number(5, .dots): 4, .number(7, .dots): 3])
    #expect(target.hasJokerGroups)
    #expect(target.groups.map(\.groupIndex) == [0, 1, 2, 3, 4])
    #expect(target.groups.map(\.jokerOK) == [false, true, true, true, false])
    #expect(target.tiles.count == 14)
  }

  @Test func everyPracticeTargetHasFourteenTilesAndRespectsSupply() {
    let analyzer = Analyzer(card: PracticeCard.card)
    #expect(!analyzer.targets.isEmpty)
    for target in analyzer.targets {
      #expect(target.tiles.count == 14)
      let counts = target.tiles.counts
      for (tile, count) in counts { #expect(count <= tile.copies + 8) }
      for (tile, count) in target.plainNeed { #expect(count <= tile.copies) }
    }
    for lineTargets in analyzer.lineTargets { #expect(!lineTargets.isEmpty) }
  }

  @Test func signaturesAreUniquePerLine() {
    for line in PracticeCard.card.lines {
      let sigs = Engine.expand(line).map(\.signature)
      #expect(Set(sigs).count == sigs.count, "\(line.displayName)")
    }
  }
}

struct EvaluateTests {
  private let name = "Odd Climb"  // 11/x 333/x 5555/x 777/x 99/x, exposed

  @Test func perfectRackIsDistanceZero() {
    let target = pick(name, x: .dots)
    let result = evaluate(target, name, rack: target.tiles)
    #expect(result.distance == 0)
    #expect(result.possible)
    #expect(result.missing.isEmpty)
    #expect(result.jokersUsed == 0)
    #expect(result.unusedRack.isEmpty)
    #expect(result.usedRack.values.reduce(0, +) == 14)
  }

  @Test func missingOneTileOfAPairIsDistanceOneAndNotJokerable() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    rack.remove(at: rack.firstIndex(of: .number(1, .dots))!)
    let result = evaluate(target, name, rack: rack)
    #expect(result.distance == 1)
    #expect(result.missing == [MissingTile(tile: .number(1, .dots), count: 1, jokerOK: false)])
  }

  @Test func aJokerCannotFillAPair() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    rack.remove(at: rack.firstIndex(of: .number(1, .dots))!)
    rack.append(.joker)
    let result = evaluate(target, name, rack: rack)
    #expect(result.distance == 1)
    #expect(result.jokersUsed == 0)
    #expect(result.unusedRack == [.joker])
  }

  @Test func twoJokersCoverAPungDeficit() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    for _ in 0..<2 { rack.remove(at: rack.firstIndex(of: .number(7, .dots))!) }
    rack.append(contentsOf: [.joker, .joker])
    let result = evaluate(target, name, rack: rack)
    #expect(result.distance == 0)
    #expect(result.jokersUsed == 2)
    #expect(result.usedRack[.joker] == 2)
    #expect(result.missing.isEmpty)
  }

  @Test func jokerShortfallIsReportedAsJokerOKMissing() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    for _ in 0..<2 { rack.remove(at: rack.firstIndex(of: .number(7, .dots))!) }
    rack.append(.joker)
    let result = evaluate(target, name, rack: rack)
    #expect(result.distance == 1)
    #expect(result.jokersUsed == 1)
    #expect(result.missing == [MissingTile(tile: .number(7, .dots), count: 1, jokerOK: true)])
  }

  @Test func emptyRackIsFourteenAway() {
    let target = pick(name, x: .dots)
    let result = evaluate(target, name, rack: [])
    #expect(result.distance == 14)
    #expect(result.missing.map(\.count).reduce(0, +) == 14)
  }

  @Test func matchingExposureCountsAsComplete() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    for _ in 0..<3 { rack.remove(at: rack.firstIndex(of: .number(3, .dots))!) }
    let pung = Exposure(tiles: [.number(3, .dots), .number(3, .dots), .number(3, .dots)])
    let result = evaluate(target, name, rack: rack, exposures: [pung])
    #expect(result.distance == 0)
    #expect(result.possible)
  }

  @Test func exposureWithJokersMatches() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    for _ in 0..<4 { rack.remove(at: rack.firstIndex(of: .number(5, .dots))!) }
    let kong = Exposure(tiles: [.number(5, .dots), .number(5, .dots), .joker, .joker])
    let result = evaluate(target, name, rack: rack, exposures: [kong])
    #expect(result.distance == 0)
    #expect(!result.jokerlessPossible)
  }

  @Test func wrongSizeExposureIsImpossible() {
    let target = pick(name, x: .dots)
    var rack = target.tiles
    for _ in 0..<3 { rack.remove(at: rack.firstIndex(of: .number(5, .dots))!) }
    // 5 Dot is a kong in this hand; exposing a pung of it does not match.
    let pung = Exposure(tiles: [.number(5, .dots), .number(5, .dots), .number(5, .dots)])
    let result = evaluate(target, name, rack: rack, exposures: [pung])
    #expect(!result.possible)
    #expect(result.impossibleReason == .exposure)
  }

  @Test func exposureOfTheWrongTileIsImpossible() {
    let target = pick(name, x: .dots)
    let pung = Exposure(tiles: [.number(4, .dots), .number(4, .dots), .number(4, .dots)])
    let result = evaluate(target, name, rack: [], exposures: [pung])
    #expect(result.impossibleReason == .exposure)
  }

  @Test func invalidExposureShapesAreImpossible() {
    let target = pick(name, x: .dots)
    let allJokers = Exposure(tiles: [.joker, .joker, .joker])
    let mixed = Exposure(tiles: [.number(3, .dots), .number(4, .dots), .joker])
    #expect(evaluate(target, name, rack: [], exposures: [allJokers]).impossibleReason == .exposure)
    #expect(evaluate(target, name, rack: [], exposures: [mixed]).impossibleReason == .exposure)
  }

  @Test func eachGroupCanBeMatchedByOnlyOneExposure() {
    let target = pick(name, x: .dots)
    let pung = Exposure(tiles: [.number(3, .dots), .number(3, .dots), .number(3, .dots)])
    let result = evaluate(target, name, rack: [], exposures: [pung, pung])
    #expect(result.impossibleReason == .exposure)
  }

  @Test func concealedLineWithExposureIsImpossible() {
    let concealedName = "Even Pairs"  // concealed
    let target = targets(concealedName)[0]
    let pung = Exposure(tiles: [.number(2, .dots), .number(2, .dots), .number(2, .dots)])
    let result = evaluate(target, concealedName, rack: [], exposures: [pung])
    #expect(!result.possible)
    #expect(result.impossibleReason == .concealed)
  }

  @Test func concealedLineWithoutExposureIsFine() {
    let concealedName = "Even Pairs"
    let target = targets(concealedName)[0]
    let result = evaluate(target, concealedName, rack: target.tiles)
    #expect(result.distance == 0)
    #expect(result.possible)
  }

  @Test func unusedRackAndUsedRackPartitionTheRack() {
    let target = pick(name, x: .dots)
    let rack: [Tile] = [
      .number(1, .dots), .number(3, .dots), .number(3, .dots), .flower, .wind(.north), .joker,
      .number(9, .cracks),
    ]
    let result = evaluate(target, name, rack: rack)
    var combined = result.usedRack
    for tile in result.unusedRack { combined[tile, default: 0] += 1 }
    #expect(combined == rack.counts)
    #expect(result.unusedRack == result.unusedRack.sorted())
    #expect(result.jokersUsed == 1)
  }

  @Test func jokerlessPossibleTracksLiveNaturals() {
    let target = pick(name, x: .dots)
    // Three of the four 5 Dots are gone, and we hold none: a jokerless kong of 5s is impossible.
    var live = Engine.liveCounts(PlayerView(), seen: [:])
    live[.number(5, .dots)] = 3
    let result = evaluate(target, name, rack: [], live: live)
    #expect(!result.jokerlessPossible)
    #expect(result.possible)
    let fresh = evaluate(target, name, rack: [], live: Engine.liveCounts(PlayerView(), seen: [:]))
    #expect(fresh.jokerlessPossible)
  }
}

struct LiveAndDeadTests {
  @Test func liveCountsSubtractRackExposuresAndSeen() {
    let view = PlayerView(
      rack: [.number(5, .dots), .joker],
      exposures: [Exposure(tiles: [.number(5, .dots), .number(5, .dots), .joker])])
    let live = Engine.liveCounts(view, seen: [.number(5, .dots): 1, .joker: 2])
    #expect(live[.number(5, .dots)] == 0)  // 4 − 1 rack − 2 exposed − 1 seen = 0
    #expect(live[.joker] == 8 - 1 - 1 - 2)
    #expect(live[.flower] == 8)
    #expect(live.count == 36)
  }

  @Test func liveCountsFloorAtZero() {
    let live = Engine.liveCounts(PlayerView(rack: [.wind(.north)]), seen: [.wind(.north): 9])
    #expect(live[.wind(.north)] == 0)
  }

  @Test func needingANorthPairWhenThreeAreSeenIsDead() {
    let target = Target(
      lineID: "t", variantIndex: 0, binding: SuitBinding(),
      groups: [
        TargetGroup(tile: .wind(.north), count: 2, jokerOK: false, groupIndex: 0),
        TargetGroup(tile: .number(1, .dots), count: 3, jokerOK: true, groupIndex: 1),
      ])
    let view = PlayerView(rack: [])
    let live = Engine.liveCounts(view, seen: [.wind(.north): 3])
    let result = Engine.evaluate(target, line: line("Four Winds"), view: view, live: live)
    #expect(!result.possible)
    #expect(result.impossibleReason == .dead)
    #expect(result.deadTiles == [.wind(.north)])
    #expect(result.distance == 5)
    // Two North visible is still fine.
    let fine = Engine.evaluate(
      target, line: line("Four Winds"), view: view, live: Engine.liveCounts(view, seen: [.wind(.north): 2]))
    #expect(fine.possible)
  }

  @Test func oneMissingNorthWithNoneLeftIsDeadButOneLeftIsAlive() {
    let target = Target(
      lineID: "t", variantIndex: 0, binding: SuitBinding(),
      groups: [TargetGroup(tile: .wind(.north), count: 2, jokerOK: false, groupIndex: 0)])
    let view = PlayerView(rack: [.wind(.north)])
    // We hold one North and three more are visible: the second one we need can't exist.
    var result = Engine.evaluate(
      target, line: line("Four Winds"), view: view, live: Engine.liveCounts(view, seen: [.wind(.north): 3]))
    #expect(!result.possible)
    #expect(result.deadTiles == [.wind(.north)])
    // With only two visible, one North is still out there.
    result = Engine.evaluate(
      target, line: line("Four Winds"), view: view, live: Engine.liveCounts(view, seen: [.wind(.north): 2]))
    #expect(result.possible)
    #expect(result.distance == 1)
  }

  @Test func jokerableShortfallBeyondWhatIsLeftIsDead() {
    // Need a pung of 3 Dots with nothing in hand; every 3 Dot and every joker is gone.
    let target = Target(
      lineID: "t", variantIndex: 0, binding: SuitBinding(),
      groups: [TargetGroup(tile: .number(3, .dots), count: 3, jokerOK: true, groupIndex: 0)])
    let view = PlayerView(rack: [])
    var seen: TileCounts = [.number(3, .dots): 4, .joker: 8]
    var result = Engine.evaluate(target, line: line("Four Winds"), view: view, live: Engine.liveCounts(view, seen: seen))
    #expect(result.impossibleReason == .dead)
    seen = [.number(3, .dots): 4, .joker: 5]
    result = Engine.evaluate(target, line: line("Four Winds"), view: view, live: Engine.liveCounts(view, seen: seen))
    #expect(result.possible)  // 3 jokers still out there
    #expect(result.liveOuts == 3)
  }

  @Test func liveOutsCountLiveCopiesOfMissingTilesPlusJokers() {
    let target = Target(
      lineID: "t", variantIndex: 0, binding: SuitBinding(),
      groups: [
        TargetGroup(tile: .wind(.north), count: 2, jokerOK: false, groupIndex: 0),
        TargetGroup(tile: .number(3, .dots), count: 3, jokerOK: true, groupIndex: 1),
      ])
    let view = PlayerView(rack: [.wind(.north)])
    let live = Engine.liveCounts(view, seen: [:])
    let result = Engine.evaluate(target, line: line("Four Winds"), view: view, live: live)
    // Missing: 1 North (3 live) + a 3 Dot pung (4 live + 8 live jokers).
    #expect(result.liveOuts == 3 + 4 + 8)
  }
}

struct BruteForceTests {
  private func bruteDistance(slots: [(tile: Tile, jokerOK: Bool)], rack: [Tile]) -> Int {
    var counts = rack.counts
    func best(_ i: Int) -> Int {
      if i == slots.count { return 0 }
      var result = best(i + 1)
      let slot = slots[i]
      if (counts[slot.tile] ?? 0) > 0 {
        counts[slot.tile]! -= 1
        result = max(result, 1 + best(i + 1))
        counts[slot.tile]! += 1
      }
      if slot.jokerOK, (counts[.joker] ?? 0) > 0 {
        counts[.joker]! -= 1
        result = max(result, 1 + best(i + 1))
        counts[.joker]! += 1
      }
      return result
    }
    return slots.count - best(0)
  }

  @Test func evaluateMatchesBruteForceOverRandomSmallCases() {
    var rng = SeededRandom(seed: 20261008)
    let pool: [Tile] = [.number(1, .cracks), .number(2, .cracks), .wind(.north), .wind(.east), .dragon(.red)]
    for _ in 0..<500 {
      var groups: [TargetGroup] = []
      var slotCount = 0
      let groupTarget = 2 + Int(rng.next() % 3)
      while groups.count < groupTarget {
        let count = 1 + Int(rng.next() % 4)
        if slotCount + count > 8 { break }
        let tile = pool[Int(rng.next() % UInt64(pool.count))]
        groups.append(TargetGroup(tile: tile, count: count, jokerOK: count >= 3, groupIndex: groups.count))
        slotCount += count
      }
      if groups.isEmpty { continue }
      var rack: [Tile] = []
      let rackSize = Int(rng.next() % 11)
      for _ in 0..<rackSize {
        if rng.next() % 4 == 0 {
          rack.append(.joker)
        } else {
          rack.append(pool[Int(rng.next() % UInt64(pool.count))])
        }
      }
      let target = Target(lineID: "t", variantIndex: 0, binding: SuitBinding(), groups: groups)
      let slots = groups.flatMap { g in Array(repeating: (tile: g.tile, jokerOK: g.jokerOK), count: g.count) }
      let expected = bruteDistance(slots: slots, rack: rack)
      let result = Engine.evaluate(target, line: line("Four Winds"), view: PlayerView(rack: rack), live: nil)
      #expect(result.distance == expected, "groups \(groups) rack \(rack)")
      #expect(result.usedRack.values.reduce(0, +) + result.distance == slotCount)
    }
  }
}

struct AnalyzeTests {
  private let analyzer = Analyzer(card: PracticeCard.card)

  @Test func returnsEveryLineExactlyOnce() {
    let results = analyzer.analyze(PlayerView(rack: Wall.deal(seed: 5).hand))
    #expect(results.count == 37)
    #expect(Set(results.map(\.line.id)).count == 37)
  }

  @Test func aCompleteHandRanksFirstAtDistanceZero() {
    let target = pick("Even Climb", x: .bams)
    let results = analyzer.analyze(PlayerView(rack: target.tiles))
    #expect(results.first?.line.name == "Even Climb")
    #expect(results.first?.best.distance == 0)
    #expect(results.first?.best.target.binding.x == .bams)
  }

  @Test func resultsAreSortedByTheComparator() {
    for seed in UInt64(1)...25 {
      let results = analyzer.analyze(PlayerView(rack: Wall.deal(seed: seed).hand))
      for (a, b) in zip(results, results.dropFirst()) {
        if a.best.possible != b.best.possible {
          #expect(a.best.possible)
          continue
        }
        if a.best.distance != b.best.distance {
          #expect(a.best.distance < b.best.distance)
          continue
        }
        let plainA = a.best.missing.filter { !$0.jokerOK }.reduce(0) { $0 + $1.count }
        let plainB = b.best.missing.filter { !$0.jokerOK }.reduce(0) { $0 + $1.count }
        if plainA != plainB {
          #expect(plainA < plainB)
          continue
        }
        if a.best.liveOuts != b.best.liveOuts {
          #expect(a.best.liveOuts > b.best.liveOuts)
          continue
        }
        #expect(a.line.points >= b.line.points)
      }
    }
  }

  @Test func tiesAreBrokenByPointsThenCardOrder() throws {
    let text = """
      # Test
      NNNN EEE WWW SSSS ; 25 ; X ; First
      NNNN EEE WWW SSSS ; 25 ; X ; Second
      NNNN EEE WWW SSSS ; 30 ; X ; Third
      """
    let parsed = Notation.parseCardFile(text)
    #expect(parsed.errors.isEmpty)
    let card = Notation.makeCard(from: parsed, id: "t", createdAt: Date(timeIntervalSince1970: 0))
    let results = Analyzer(card: card).analyze(PlayerView(rack: []))
    // Identical lines have different IDs only through their position (the hash is the same), so order is
    // by points first, then card order.
    #expect(results.map { $0.line.name } == ["Third", "First", "Second"])
  }

  @Test func impossibleLinesSortAfterPossibleOnes() {
    let target = pick("Even Climb", x: .bams)
    // The 2 Bam pung is exposed, so Even Climb is still alive and concealed lines are not.
    let exposure = Exposure(tiles: [.number(2, .bams), .number(2, .bams), .number(2, .bams)])
    let rack = target.tiles.filter { $0 != .number(2, .bams) }
    let results = analyzer.analyze(PlayerView(rack: rack, exposures: [exposure]))
    let firstImpossible = results.firstIndex { !$0.best.possible } ?? results.count
    #expect(results[firstImpossible...].allSatisfy { !$0.best.possible })
    #expect(results.first?.line.name == "Even Climb")
    #expect(results.contains { $0.best.impossibleReason == .concealed })
  }

  @Test func seenTilesMakeLinesDead() {
    // Compass Dragons needs a single North, which can't be made once all four are visible.
    let results = analyzer.analyze(PlayerView(rack: []), seen: [.wind(.north): 4])
    let compass = results.first { $0.line.name == "Compass Dragons" }
    #expect(compass?.best.possible == false)
    #expect(compass?.best.impossibleReason == .dead)
    #expect(compass?.best.deadTiles == [.wind(.north)])
    // Four Winds can still use jokers for the Norths.
    #expect(results.first { $0.line.name == "Four Winds" }?.best.possible == true)
  }

  @Test func alternativesCountOtherPossibleTargets() {
    let results = analyzer.analyze(PlayerView(rack: []))
    let evenClimb = results.first { $0.line.name == "Even Climb" }
    #expect(evenClimb?.alternatives == 2)
    let fourWinds = results.first { $0.line.name == "Four Winds" }
    #expect(fourWinds?.alternatives == 0)
  }

  @Test func analysisIsFastEnough() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      for seed in UInt64(1)...200 {
        _ = analyzer.analyze(PlayerView(rack: Wall.deal(seed: seed).hand))
      }
    }
    #expect(elapsed < .seconds(5), "200 analyses took \(elapsed)")
  }
}
