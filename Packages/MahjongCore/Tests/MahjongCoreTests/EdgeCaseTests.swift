import Foundation
import Testing

@testable import MahjongCore

/// SPEC §19.4 step 4: sessions of every size and length stay balanced and fast.
struct SessionEdgeCaseTests {
  private func randomSession(seats: Int, hands: Int, seed: UInt64) -> Session {
    var rng = SeededRandom(seed: seed)
    let ids = (0..<seats).map { "p\($0)" }
    var s = Session(id: "s", createdAt: Date(timeIntervalSince1970: 0), seatIDs: ids)
    for n in 0..<hands {
      let kind: HandKind
      switch rng.next() % 10 {
      case 0:
        kind = .wall(note: nil)
      case 1:
        let a = Int(rng.next() % UInt64(seats))
        kind = .adjustment(fromID: ids[a], toID: ids[(a + 1) % seats], points: Int(rng.next() % 50), note: nil)
      default:
        let w = Int(rng.next() % UInt64(seats))
        let selfPick = rng.next() % 3 == 0
        let d = (w + 1 + Int(rng.next() % UInt64(seats - 1))) % seats
        kind = .mahjong(
          MahjongInput(
            winnerID: ids[w], discarderID: selfPick ? nil : ids[d], basePoints: 25 + Int(rng.next() % 4) * 5,
            jokerless: rng.next() % 4 == 0))
      }
      s = Scoring.adding(kind, to: s, id: "h\(n)", at: Date(timeIntervalSince1970: Double(n)))
    }
    return s
  }

  @Test func everyTableSizeStaysBalanced() {
    for seats in 3...4 {
      for seed in UInt64(1)...25 {
        let s = randomSession(seats: seats, hands: 40, seed: seed)
        #expect(Scoring.totals(s).values.reduce(0, +) == 0, "\(seats) players, seed \(seed)")
        let money = Scoring.moneyTotals(s)
        #expect(money.values.reduce(0, +) == 0)
        let transfers = Scoring.settleUp(money)
        var net = money
        for t in transfers {
          net[t.fromID, default: 0] += t.cents
          net[t.toID, default: 0] -= t.cents
        }
        #expect(net.values.allSatisfy { $0 == 0 }, "settle-up clears everything")
      }
    }
  }

  @Test func aTwoHundredHandSessionIsQuick() {
    let start = Date()
    let s = randomSession(seats: 4, hands: 200, seed: 99)
    for _ in 0..<20 { _ = Scoring.totals(s); _ = Scoring.moneyTotals(s) }
    #expect(s.hands.count == 200)
    #expect(Date().timeIntervalSince(start) < 3, "building and totalling 200 hands twenty times")
  }

  @Test func changingTheRulesMidSessionRecomputesEverything() {
    let s = randomSession(seats: 4, hands: 30, seed: 5)
    var rules = s.rules
    if let i = rules.rules.firstIndex(where: { $0.id == RuleID.blanks }) { rules.rules[i].isEnabled = true }
    let changed = Scoring.withRules(rules, s)
    #expect(Scoring.totals(changed) == Scoring.totals(s), "blanks never change scoring")
    #expect(Scoring.totals(changed).values.reduce(0, +) == 0)
  }
}

/// Analysis with nothing to analyse.
struct EmptyCardEdgeCaseTests {
  @Test func aCardWithNoHandsNeverCrashesTheEngine() {
    let card = Card(id: "empty", name: "Empty", year: nil, builtIn: false, lines: [], createdAt: Date(), updatedAt: Date())
    let analyzer = Analyzer(card: card)
    let view = PlayerView(rack: Array(Tile.allCases.prefix(13)))
    #expect(analyzer.analyze(view).isEmpty)
    #expect(analyzer.suggestPasses(view, count: 3).passes.count <= 3)
    // Practice quietly falls back to the Practice Card.
    let e = Exercises.make(ExerciseID(type: .pickHand, seed: 1, difficulty: 1), card: card)
    #expect(!e.choices.isEmpty)
  }

  @Test func aRackOfBlanksAndJokersIsHandled() {
    let analyzer = Analyzer(card: PracticeCard.card)
    let view = PlayerView(rack: [.blank, .blank, .joker, .joker, .flower, .flower] + Array(Tile.allCases.prefix(7)))
    #expect(!analyzer.analyze(view).isEmpty)
    #expect(analyzer.suggestPasses(view, count: 3).passes.allSatisfy { $0.tile != .joker })
  }
}
