import Foundation
import Testing

@testable import MahjongCore

private let abcd = ["A", "B", "C", "D"]

private func win(
  _ winner: String = "A", from discarder: String? = nil, points: Int = 25, jokerless: Bool = false,
  noJokerGroups: Bool = false, label: String? = nil, cardID: String? = nil, lineID: String? = nil
) -> HandKind {
  .mahjong(
    MahjongInput(
      winnerID: winner, discarderID: discarder, cardID: cardID, lineID: lineID, lineLabel: label,
      basePoints: points, jokerless: jokerless, lineHasNoJokerGroups: noJokerGroups))
}

private func pay(_ kind: HandKind, seats: [String] = abcd, rules: RuleSet = .standard) -> [String: Int] {
  Scoring.payments(for: kind, seats: seats, rules: rules)
}

private func session(
  seats: [String] = abcd, start: Int = 0, rules: RuleSet = .standard, id: String = "s1"
) -> Session {
  Session(id: id, createdAt: Date(timeIntervalSince1970: 0), seatIDs: seats, startDealerIndex: start, rules: rules)
}

private func add(_ kind: HandKind, _ s: Session, _ id: String) -> Session {
  Scoring.adding(kind, to: s, id: id, at: Date(timeIntervalSince1970: Double(s.hands.count + 1) * 100))
}

struct PayoutTests {
  @Test func bDiscards() {
    #expect(pay(win(from: "B")) == ["A": 100, "B": -50, "C": -25, "D": -25])
  }

  @Test func selfPick() {
    #expect(pay(win()) == ["A": 150, "B": -50, "C": -50, "D": -50])
  }

  @Test func bDiscardsJokerless() {
    #expect(pay(win(from: "B", jokerless: true)) == ["A": 200, "B": -100, "C": -50, "D": -50])
  }

  @Test func selfPickJokerless() {
    #expect(pay(win(jokerless: true)) == ["A": 300, "B": -100, "C": -100, "D": -100])
  }

  @Test func jokerlessOnNoJokerLineGetsNoBonusByDefault() {
    #expect(
      pay(win(from: "B", jokerless: true, noJokerGroups: true)) == ["A": 100, "B": -50, "C": -25, "D": -25])
  }

  @Test func jokerlessOnNoJokerLineGetsBonusWhenRuleEnabled() {
    var rules = RuleSet.standard
    rules.jokerlessBonusForNoJokerLines = true
    #expect(
      pay(win(from: "B", jokerless: true, noJokerGroups: true), rules: rules)
        == ["A": 200, "B": -100, "C": -50, "D": -50])
  }

  @Test func threePlayers() {
    #expect(pay(win(from: "B"), seats: ["A", "B", "C"]) == ["A": 75, "B": -50, "C": -25])
  }

  @Test func customMultipliers() {
    var rules = RuleSet.standard
    rules.discarderMultiplier = 3
    rules.othersOnDiscardMultiplier = 0
    #expect(pay(win(from: "C"), rules: rules) == ["A": 75, "B": 0, "C": -75, "D": 0])
  }

  @Test func wallGameMovesNothing() {
    #expect(pay(.wall(note: nil)) == ["A": 0, "B": 0, "C": 0, "D": 0])
  }

  @Test func adjustmentMovesPointsBetweenTwoPlayers() {
    let kind = HandKind.adjustment(fromID: "B", toID: "D", points: 10, note: "penalty")
    #expect(pay(kind) == ["A": 0, "B": -10, "C": 0, "D": 10])
  }

  @Test func invalidDiscarderIsTreatedAsSelfPick() {
    #expect(pay(win(from: "A")) == pay(win()))
    #expect(pay(win(from: "Z")) == pay(win()))
  }

  @Test func unseatedWinnerPaysNothing() {
    #expect(pay(win("Z")).values.allSatisfy { $0 == 0 })
  }

  @Test func everyHandIsZeroSum() {
    var rules = RuleSet.standard
    for seats in [["A", "B", "C"], abcd] {
      for winner in seats {
        for thrower in [nil] + seats.map { Optional($0) } {
          for jokerless in [false, true] {
            for noJoker in [false, true] {
              for bonus in [false, true] {
                rules.jokerlessBonusForNoJokerLines = bonus
                for points in [1, 25, 30, 75] {
                  let result = pay(
                    win(winner, from: thrower, points: points, jokerless: jokerless, noJokerGroups: noJoker),
                    seats: seats, rules: rules)
                  #expect(result.values.reduce(0, +) == 0)
                  #expect(Set(result.keys) == Set(seats))
                  #expect((result[winner] ?? 0) >= 0)
                }
              }
            }
          }
        }
      }
    }
  }
}

struct SessionLogicTests {
  @Test func dealerAdvancesOnMahjongAndWallButNotAdjustments() {
    var s = session(start: 1)
    #expect(Scoring.currentDealerID(s) == "B")
    s = add(win("A"), s, "h1")
    #expect(Scoring.currentDealerID(s) == "C")
    s = add(.adjustment(fromID: "A", toID: "B", points: 5, note: nil), s, "h2")
    #expect(Scoring.currentDealerID(s) == "C")
    s = add(.wall(note: nil), s, "h3")
    #expect(Scoring.currentDealerID(s) == "D")
    s = add(win("D"), s, "h4")
    #expect(Scoring.currentDealerID(s) == "A")
    #expect(s.hands.map(\.dealerID) == ["B", "C", "C", "D"])
  }

  @Test func totalsAndMoney() {
    var rules = RuleSet.standard
    rules.money = MoneySettings(enabled: true, centsPerPoint: 2, currencySymbol: "$")
    var s = session(rules: rules)
    s = add(win("A", from: "B"), s, "h1")
    s = add(win("C"), s, "h2")
    let totals = Scoring.totals(s)
    #expect(totals == ["A": 50, "B": -100, "C": 125, "D": -75])
    #expect(totals.values.reduce(0, +) == 0)
    #expect(Scoring.moneyTotals(s)["A"] == (totals["A"] ?? 0) * 2)
  }

  @Test func totalsStartAtZeroForEverySeat() {
    #expect(Scoring.totals(session()) == ["A": 0, "B": 0, "C": 0, "D": 0])
  }

  @Test func editingRecomputesTotalsAndLaterDealers() {
    var s = session()
    s = add(win("A", from: "B"), s, "h1")
    s = add(win("B"), s, "h2")
    #expect(s.hands[1].dealerID == "B")
    // Turn hand 1 into a wall game: no payments, but the deal still advances.
    var edited = Scoring.editing(handID: "h1", to: .wall(note: nil), in: s)
    #expect(edited.hands[0].payments.values.allSatisfy { $0 == 0 })
    #expect(edited.hands[1].dealerID == "B")
    // Turn it into an adjustment: the deal no longer advances after it.
    edited = Scoring.editing(
      handID: "h1", to: .adjustment(fromID: "A", toID: "C", points: 10, note: nil), in: s)
    #expect(edited.hands[1].dealerID == "A")
    #expect(Scoring.totals(edited)["C"] == 10 - 50)
    // Editing the points changes the totals.
    let bigger = Scoring.editing(handID: "h1", to: win("A", from: "B", points: 50), in: s)
    #expect(Scoring.totals(bigger)["A"] == 200 - 50)
    // Unknown IDs are ignored.
    #expect(Scoring.editing(handID: "nope", to: .wall(note: nil), in: s) == s)
  }

  @Test func removingAndUndoing() {
    var s = session()
    s = add(win("A"), s, "h1")
    s = add(win("B"), s, "h2")
    s = add(win("C"), s, "h3")
    let removed = Scoring.removing(handID: "h1", from: s)
    #expect(removed.hands.map(\.id) == ["h2", "h3"])
    #expect(removed.hands.map(\.dealerID) == ["A", "B"])
    let undone = Scoring.undoingLast(s)
    #expect(undone.hands.map(\.id) == ["h1", "h2"])
    #expect(Scoring.currentDealerID(undone) == "C")
    #expect(Scoring.undoingLast(session()) == session())
  }

  @Test func withRulesRecomputesEveryHand() {
    var s = session()
    s = add(win("A", from: "B"), s, "h1")
    s = add(win("A"), s, "h2")
    var rules = RuleSet.standard
    rules.discarderMultiplier = 1
    rules.selfPickMultiplier = 1
    let changed = Scoring.withRules(rules, s)
    #expect(changed.rules == rules)
    #expect(changed.hands[0].payments == ["A": 75, "B": -25, "C": -25, "D": -25])
    #expect(changed.hands[1].payments == ["A": 75, "B": -25, "C": -25, "D": -25])
  }

  @Test func endingAndReopening() {
    let s = session()
    let end = Date(timeIntervalSince1970: 999)
    let ended = Scoring.ending(s, at: end)
    #expect(ended.endedAt == end)
    #expect(Scoring.reopening(ended).endedAt == nil)
  }

  @Test func sessionRoundTripsThroughJSON() throws {
    var s = session()
    s = add(win("A", from: "B", label: "Even Climb"), s, "h1")
    s = add(.adjustment(fromID: "A", toID: "C", points: 5, note: "x"), s, "h2")
    s = add(.wall(note: nil), s, "h3")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let back = try decoder.decode(Session.self, from: encoder.encode(s))
    #expect(back == s)
  }
}

struct MoneyAndSettleUpTests {
  @Test func formatMoney() {
    #expect(Scoring.formatMoney(cents: 125, symbol: "$") == "$1.25")
    #expect(Scoring.formatMoney(cents: -50, symbol: "$") == "\u{2212}$0.50")
    #expect(Scoring.formatMoney(cents: 0, symbol: "$") == "$0.00")
    #expect(Scoring.formatMoney(cents: 5, symbol: "€") == "€0.05")
    #expect(Scoring.formatMoney(cents: 100_000, symbol: "$") == "$1000.00")
  }

  @Test func settleUpSimple() {
    let transfers = Scoring.settleUp(["A": 125, "B": -100, "C": -25, "D": 0])
    #expect(
      transfers == [Transfer(fromID: "B", toID: "A", cents: 100), Transfer(fromID: "C", toID: "A", cents: 25)])
  }

  @Test func settleUpNothingOwed() {
    #expect(Scoring.settleUp(["A": 0, "B": 0]).isEmpty)
    #expect(Scoring.settleUp([:]).isEmpty)
  }

  @Test func settleUpPropertiesOverRandomBalances() {
    var rng = SeededRandom(seed: 2026)
    for _ in 0..<300 {
      let n = Int(rng.next() % 2) + 3
      var balances: [String: Int] = [:]
      var sum = 0
      for i in 0..<(n - 1) {
        let value = Int(rng.next() % 4001) - 2000
        balances["P\(i)"] = value
        sum += value
      }
      balances["P\(n - 1)"] = -sum
      let transfers = Scoring.settleUp(balances)
      var net: [String: Int] = [:]
      for t in transfers {
        #expect(t.cents > 0)
        net[t.fromID, default: 0] -= t.cents
        net[t.toID, default: 0] += t.cents
      }
      for (id, value) in balances { #expect((net[id] ?? 0) == value) }
      #expect(transfers.count <= n - 1)
      #expect(transfers.map(\.cents) == transfers.map(\.cents).sorted(by: >))
    }
  }
}

struct StatsTests {
  private func fixture() -> [Session] {
    var rules = RuleSet.standard
    rules.money = MoneySettings(enabled: true, centsPerPoint: 1, currencySymbol: "$")
    var s1 = session(rules: rules, id: "s1")
    s1 = add(win("A", from: "B", label: "Even Climb", cardID: "card", lineID: "L1"), s1, "a1")
    s1 = add(win("A", label: "Even Climb", cardID: "card", lineID: "L1"), s1, "a2")
    s1 = add(win("B", from: "A", points: 30, jokerless: true, label: "Odd Climb", cardID: "card", lineID: "L2"), s1, "a3")
    s1 = add(.wall(note: nil), s1, "a4")
    s1 = add(.adjustment(fromID: "A", toID: "B", points: 5, note: nil), s1, "a5")
    s1 = Scoring.ending(s1, at: Date(timeIntervalSince1970: 5000))

    var s2 = session(seats: ["A", "C", "D"], rules: .standard, id: "s2")
    s2 = add(win("C", from: "A", points: 50, label: "Odd Climb", cardID: "card", lineID: "L2"), s2, "b1")
    s2 = add(win("A", jokerless: true, label: "Even Climb", cardID: "card", lineID: "L1"), s2, "b2")
    s2 = Scoring.ending(s2, at: Date(timeIntervalSince1970: 9000))
    return [s1, s2]
  }

  @Test func statsForPlayerA() {
    let sessions = fixture()
    let stats = Scoring.playerStats("A", sessions: sessions)
    #expect(stats.sessionsPlayed == 2)
    #expect(stats.handsPlayed == 4 + 2)  // wall counts, adjustment does not
    #expect(stats.wins == 3)
    #expect(stats.winRate == 3.0 / 6.0)
    #expect(stats.selfPicks == 2)
    #expect(stats.jokerlessWins == 1)
    #expect(stats.avgWinPoints == 25.0)
    #expect(stats.timesDiscardedWinner == 2)
    // s2 b2: self-pick jokerless with 2 others paying 25*2*2 = 100 each = 200.
    #expect(stats.biggestWin?.points == 200)
    #expect(stats.biggestWin?.lineLabel == "Even Climb")
    #expect(stats.favoriteLines == [LineCount(label: "Even Climb", count: 3)])
    let s1Total = Scoring.totals(sessions[0])["A"] ?? 0
    let s2Total = Scoring.totals(sessions[1])["A"] ?? 0
    #expect(stats.netPoints == s1Total + s2Total)
    // Only s1 had money on.
    #expect(stats.netCents == s1Total)
  }

  @Test func statsForPlayerWhoSatOutASession() {
    let stats = Scoring.playerStats("B", sessions: fixture())
    #expect(stats.sessionsPlayed == 1)
    #expect(stats.wins == 1)
    #expect(stats.jokerlessWins == 1)
    #expect(stats.timesDiscardedWinner == 1)
    #expect(stats.biggestWin?.lineLabel == "Odd Climb")
  }

  @Test func sessionWinsCountEndedSessionsWhereTheyFinishedTop() {
    let sessions = fixture()
    let totals1 = Scoring.totals(sessions[0])
    let top1 = totals1.max { $0.value < $1.value }?.key ?? ""
    #expect(Scoring.playerStats(top1, sessions: sessions).sessionWins >= 1)
    #expect(Scoring.playerStats("C", sessions: sessions).sessionsPlayed == 2)
    // An unfinished session never counts.
    var active = sessions[0]
    active.endedAt = nil
    #expect(Scoring.playerStats(top1, sessions: [active]).sessionWins == 0)
  }

  @Test func emptyStatsForUnknownPlayer() {
    let stats = Scoring.playerStats("nobody", sessions: fixture())
    #expect(stats == PlayerStats())
  }

  @Test func lineWinsCountPerLine() {
    let wins = Scoring.lineWins(cardID: "card", sessions: fixture())
    #expect(wins == ["L1": 3, "L2": 2])
    #expect(Scoring.lineWins(cardID: "other", sessions: fixture()).isEmpty)
  }
}
