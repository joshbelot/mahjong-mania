import Foundation
import Testing

@testable import MahjongCore

private let abcd = ["A", "B", "C", "D"]

private func win(
  _ winner: String = "A", from discarder: String? = nil, points: Int = 25, jokerless: Bool = false,
  noJokerGroups: Bool = false, lineID: String? = nil, section: String? = nil, concealed: Bool = false
) -> HandKind {
  .mahjong(
    MahjongInput(
      winnerID: winner, discarderID: discarder, lineID: lineID, basePoints: points, jokerless: jokerless,
      lineHasNoJokerGroups: noJokerGroups, lineSection: section, lineConcealed: concealed))
}

private func pay(
  _ kind: HandKind, rules: RuleSet = .standard, dealer: String? = nil, seats: [String] = abcd
) -> [String: Int] {
  Scoring.payments(for: kind, seats: seats, dealerID: dealer, rules: rules)
}

private func custom(
  _ condition: RuleCondition, _ payers: PayerScope, _ action: RuleAction, enabled: Bool = true
) -> HouseRule {
  HouseRule(
    id: HouseRule.newCustomID(), isEnabled: enabled,
    custom: CustomRule(
      title: "Custom", text: "", effect: CustomEffect(condition: condition, payers: payers, action: action)))
}

private func with(_ change: (inout RuleSet) -> Void) -> RuleSet {
  var rules = RuleSet.standard
  change(&rules)
  return rules
}

private func isZeroSum(_ payments: [String: Int]) -> Bool { payments.values.reduce(0, +) == 0 }

struct RuleCatalogTests {
  @Test func standardHasEveryBuiltInAtItsDefault() {
    let rules = RuleSet.standard
    #expect(rules.rules.map(\.id) == RuleCatalog.builtIns.map(\.id))
    #expect(rules.multiple(RuleID.discarder) == 2)
    #expect(rules.multiple(RuleID.others) == 1)
    #expect(rules.multiple(RuleID.selfPick) == 2)
    #expect(rules.multiple(RuleID.jokerless) == 2)
    #expect(rules.rule(RuleID.jokerless)?.includeNoJokerHands == false)
    #expect(!rules.isOn(RuleID.discarderPaysAll))
    #expect(!rules.isOn(RuleID.blanks))
    #expect(rules.isOn(RuleID.charlestonSecond) && rules.isOn(RuleID.courtesy))
    #expect(rules.blanks == nil)
  }

  @Test func lockedRulesCannotBeSwitchedOff() {
    var rules = RuleSet.standard
    for definition in RuleCatalog.builtIns where definition.locked {
      rules.setEnabled(definition.id, false)
      #expect(rules.isOn(definition.id), "\(definition.id) is locked")
    }
    #expect(RuleCatalog.builtIns.filter(\.locked).count == 8)
    #expect(Set(RuleCatalog.builtIns.map(\.id)).count == RuleCatalog.builtIns.count)
  }

  @Test func missingBuiltInsAreAddedOnLoad() throws {
    // A rule book saved by a hypothetical earlier build that knew only one rule.
    let json = #"{"id":"x","name":"X","rules":[{"id":"pay.selfPick","isEnabled":true,"multiple":3}],"money":{"enabled":false,"centsPerPoint":1,"currencySymbol":"$"}}"#
    let rules = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
    #expect(rules.rules.map(\.id) == RuleCatalog.builtIns.map(\.id))
    #expect(rules.multiple(RuleID.selfPick) == 3)
    #expect(rules.multiple(RuleID.discarder) == 2)
  }

  @Test func customRulesKeepTheirPlaceAfterTheBuiltIns() throws {
    var rules = RuleSet.standard
    let note = HouseRule(id: "custom.note", custom: CustomRule(title: "No phones", text: "Phones away"))
    rules.addCustom(note)
    rules.addCustom(note)  // a duplicate id is ignored
    #expect(rules.customRules.count == 1)
    let data = try JSONEncoder().encode(rules)
    let back = try JSONDecoder().decode(RuleSet.self, from: data)
    #expect(back == rules)
    #expect(back.rules.last?.id == "custom.note")
    rules.removeCustom(id: "custom.note")
    #expect(rules.customRules.isEmpty)
    rules.removeCustom(id: RuleID.discarder)  // built-ins cannot be removed
    #expect(rules.rule(RuleID.discarder) != nil)
  }

  @Test func blanksOptionsRoundTrip() throws {
    var rules = RuleSet.standard
    rules.update(RuleID.blanks) {
      $0.isEnabled = true
      $0.blanks = BlankOptions(count: 4, swapForJoker: true, passInCharleston: false)
    }
    let back = try JSONDecoder().decode(RuleSet.self, from: JSONEncoder().encode(rules))
    #expect(back.blanks == BlankOptions(count: 4, swapForJoker: true, passInCharleston: false))
  }
}

struct PaymentsV2Tests {
  @Test func tableFromSpecWithStandardRules() {
    #expect(pay(win(from: "B")) == ["A": 100, "B": -50, "C": -25, "D": -25])
    #expect(pay(win()) == ["A": 150, "B": -50, "C": -50, "D": -50])
    #expect(pay(win(from: "B", jokerless: true)) == ["A": 200, "B": -100, "C": -50, "D": -50])
    #expect(pay(win(jokerless: true)) == ["A": 300, "B": -100, "C": -100, "D": -100])
    #expect(
      pay(win(from: "B", jokerless: true, noJokerGroups: true)) == ["A": 100, "B": -50, "C": -25, "D": -25])
    #expect(pay(win(from: "B"), seats: ["A", "B", "C"]) == ["A": 75, "B": -50, "C": -25])
  }

  @Test func eachRoleRuleSwitchedOffCountsAsOne() {
    #expect(
      pay(win(from: "B"), rules: with { $0.setEnabled(RuleID.discarder, false) })
        == ["A": 75, "B": -25, "C": -25, "D": -25])
    #expect(
      pay(win(from: "B"), rules: with { $0.setEnabled(RuleID.others, false) })
        == ["A": 100, "B": -50, "C": -25, "D": -25])
    #expect(
      pay(win(), rules: with { $0.setEnabled(RuleID.selfPick, false) })
        == ["A": 75, "B": -25, "C": -25, "D": -25])
    #expect(
      pay(win(from: "B", jokerless: true), rules: with { $0.setEnabled(RuleID.jokerless, false) })
        == ["A": 100, "B": -50, "C": -25, "D": -25])
  }

  @Test func othersSetToNothingPayNothing() {
    let rules = with { $0.setMultiple(RuleID.others, 0) }
    #expect(pay(win(from: "B"), rules: rules) == ["A": 50, "B": -50, "C": 0, "D": 0])
  }

  @Test func choicesChangeTheMultiple() {
    #expect(
      pay(win(from: "B", jokerless: true), rules: with { $0.setMultiple(RuleID.jokerless, 3) })
        == ["A": 300, "B": -150, "C": -75, "D": -75])
    #expect(
      pay(win(from: "B"), rules: with { $0.setMultiple(RuleID.discarder, 4) })
        == ["A": 150, "B": -100, "C": -25, "D": -25])
  }

  @Test func singlesAndPairsBonusSwitch() {
    var rules = RuleSet.standard
    rules.update(RuleID.jokerless) { $0.includeNoJokerHands = true }
    #expect(
      pay(win(from: "B", jokerless: true, noJokerGroups: true), rules: rules)
        == ["A": 200, "B": -100, "C": -50, "D": -50])
  }

  @Test func throwerPaysForEveryone() {
    let rules = with { $0.setEnabled(RuleID.discarderPaysAll, true) }
    #expect(pay(win(from: "B"), rules: rules) == ["A": 100, "B": -100, "C": 0, "D": 0])
    // A self-pick has no thrower, so everyone still pays.
    #expect(pay(win(), rules: rules) == ["A": 150, "B": -50, "C": -50, "D": -50])
  }

  @Test func wallGamesAndAdjustmentsAreUnchanged() {
    #expect(pay(.wall(note: nil)) == ["A": 0, "B": 0, "C": 0, "D": 0])
    #expect(
      pay(.adjustment(fromID: "A", toID: "C", points: 10, note: nil)) == ["A": -10, "B": 0, "C": 10, "D": 0])
  }

  @Test func customConditionsAndScopes() {
    // Self-pick: everyone pays 3x extra on top.
    let selfPick = with { $0.addCustom(custom(.selfPick, .everyone, .multiply(3))) }
    #expect(pay(win(), rules: selfPick) == ["A": 450, "B": -150, "C": -150, "D": -150])
    #expect(pay(win(from: "B"), rules: selfPick) == pay(win(from: "B")))

    // A win from a discard: only the thrower pays double again.
    let discard = with { $0.addCustom(custom(.discard, .discarderOnly, .multiply(2))) }
    #expect(pay(win(from: "B"), rules: discard) == ["A": 150, "B": -100, "C": -25, "D": -25])
    #expect(pay(win(), rules: discard) == pay(win()), "no thrower on a self-pick")

    // Everyone except the thrower pays 10 extra.
    let notThrower = with { $0.addCustom(custom(.always, .everyoneButDiscarder, .addPoints(10))) }
    #expect(pay(win(from: "B"), rules: notThrower) == ["A": 120, "B": -50, "C": -35, "D": -35])
    #expect(pay(win(), rules: notThrower) == ["A": 180, "B": -60, "C": -60, "D": -60])

    // Jokerless, concealed, East, section and line conditions.
    let jokerless = with { $0.addCustom(custom(.jokerless, .everyone, .addPoints(5))) }
    #expect(pay(win(from: "B", jokerless: true), rules: jokerless)["A"] == 215)
    #expect(pay(win(from: "B"), rules: jokerless)["A"] == 100)

    let concealed = with { $0.addCustom(custom(.concealedHand, .everyone, .multiply(2))) }
    #expect(pay(win(from: "B", concealed: true), rules: concealed)["A"] == 200)
    #expect(pay(win(from: "B"), rules: concealed)["A"] == 100)

    let east = with { $0.addCustom(custom(.eastWins, .everyone, .addPoints(10))) }
    #expect(pay(win(from: "B"), rules: east, dealer: "A")["A"] == 130)
    #expect(pay(win(from: "B"), rules: east, dealer: "B")["A"] == 100)
    #expect(pay(win(from: "B"), rules: east, dealer: nil)["A"] == 100)

    let section = with { $0.addCustom(custom(.section("Evens"), .everyone, .multiply(2))) }
    #expect(pay(win(from: "B", section: "Evens"), rules: section)["A"] == 200)
    #expect(pay(win(from: "B", section: "Odds"), rules: section)["A"] == 100)

    let line = with { $0.addCustom(custom(.line(id: "L_1", label: "Evens #1"), .everyone, .addPoints(1))) }
    #expect(pay(win(from: "B", lineID: "L_1"), rules: line)["A"] == 103)
    #expect(pay(win(from: "B", lineID: "L_2"), rules: line)["A"] == 100)
  }

  @Test func multiplyAndAddTogether() {
    var rules = RuleSet.standard
    rules.addCustom(custom(.always, .everyone, .multiply(2)))
    rules.addCustom(custom(.always, .everyone, .addPoints(7)))
    // Thrower: 25 * 2 * 2 + 7 = 107; others: 25 * 1 * 2 + 7 = 57 each.
    #expect(pay(win(from: "B"), rules: rules) == ["A": 221, "B": -107, "C": -57, "D": -57])
  }

  @Test func disabledCustomRulesAndNotesDoNothing() {
    var rules = RuleSet.standard
    rules.addCustom(custom(.always, .everyone, .multiply(5), enabled: false))
    rules.addCustom(HouseRule(id: "custom.note", custom: CustomRule(title: "Note", text: "Be kind")))
    #expect(pay(win(from: "B"), rules: rules) == pay(win(from: "B")))
  }

  @Test func thrownForEveryoneStillIncludesCustomRules() {
    var rules = RuleSet.standard
    rules.setEnabled(RuleID.discarderPaysAll, true)
    rules.addCustom(custom(.always, .everyone, .addPoints(10)))
    // Owed: B 60, C 35, D 35 = 130; B pays all of it.
    #expect(pay(win(from: "B"), rules: rules) == ["A": 130, "B": -130, "C": 0, "D": 0])
  }

  @Test func alwaysZeroSum() {
    var generator = SystemRandomNumberGenerator()
    for _ in 0..<300 {
      var rules = RuleSet.standard
      rules.setEnabled(RuleID.discarderPaysAll, Bool.random(using: &generator))
      rules.setEnabled(RuleID.others, Bool.random(using: &generator))
      rules.setMultiple(RuleID.discarder, Int.random(in: 1...4, using: &generator))
      if Bool.random(using: &generator) { rules.addCustom(custom(.always, .everyoneButDiscarder, .addPoints(3))) }
      if Bool.random(using: &generator) { rules.addCustom(custom(.discard, .discarderOnly, .multiply(3))) }
      let seats = Bool.random(using: &generator) ? abcd : ["A", "B", "C"]
      let thrower = Bool.random(using: &generator) ? seats.randomElement() : nil
      let kind = win("A", from: thrower, points: Int.random(in: 1...100, using: &generator), jokerless: Bool.random(using: &generator))
      #expect(isZeroSum(pay(kind, rules: rules, dealer: "A", seats: seats)))
    }
  }

  @Test func sessionRecomputeUsesTheDealerOfEachHand() {
    var rules = RuleSet.standard
    rules.addCustom(custom(.eastWins, .everyone, .addPoints(10)))
    var session = Session(
      id: "s", createdAt: Date(timeIntervalSince1970: 0), seatIDs: abcd, startDealerIndex: 0, rules: rules)
    session = Scoring.adding(win("A", from: "B"), to: session, id: "h1", at: Date(timeIntervalSince1970: 1))
    session = Scoring.adding(win("A", from: "B"), to: session, id: "h2", at: Date(timeIntervalSince1970: 2))
    // Hand 1: East is A (+30). Hand 2: East is B (no bonus).
    #expect(session.hands[0].payments["A"] == 130)
    #expect(session.hands[1].payments["A"] == 100)
    let again = Scoring.withRules(rules, session)
    #expect(again.hands.map(\.payments) == session.hands.map(\.payments))
  }
}

/// v1.0 stored four multipliers and a switch; those files must keep their totals.
struct RuleMigrationTests {
  /// The v1.0 payment formula, written out independently of the new code.
  private func v1Payments(
    kind input: MahjongInput, seats: [String], discarder: Int, others: Int, selfPick: Int, jokerless: Int,
    bonusForNoJokerLines: Bool
  ) -> [String: Int] {
    var result: [String: Int] = [:]
    for seat in seats { result[seat] = 0 }
    let jl = input.jokerless && (input.lineHasNoJokerGroups ? bonusForNoJokerLines : true)
    let bonus = jl ? jokerless : 1
    var thrower: String?
    if let id = input.discarderID, id != input.winnerID, seats.contains(id) { thrower = id }
    var collected = 0
    for seat in seats where seat != input.winnerID {
      let owed: Int
      if let thrower {
        owed = input.basePoints * (seat == thrower ? discarder : others) * bonus
      } else {
        owed = input.basePoints * selfPick * bonus
      }
      result[seat] = -owed
      collected += owed
    }
    result[input.winnerID] = collected
    return result
  }

  @Test func decodesTheV1Fields() throws {
    let json = #"{"id":"mine","name":"House","discarderMultiplier":3,"othersOnDiscardMultiplier":2,"selfPickMultiplier":4,"jokerlessMultiplier":3,"jokerlessBonusForNoJokerLines":true,"money":{"enabled":true,"centsPerPoint":5,"currencySymbol":"€"}}"#
    let rules = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
    #expect(rules.id == "mine" && rules.name == "House")
    #expect(rules.multiple(RuleID.discarder) == 3)
    #expect(rules.multiple(RuleID.others) == 2)
    #expect(rules.multiple(RuleID.selfPick) == 4)
    #expect(rules.multiple(RuleID.jokerless) == 3)
    #expect(rules.rule(RuleID.jokerless)?.includeNoJokerHands == true)
    #expect(rules.money == MoneySettings(enabled: true, centsPerPoint: 5, currencySymbol: "€"))
    #expect(rules.rules.map(\.id) == RuleCatalog.builtIns.map(\.id))
    // Saving writes the new shape, which reads back the same.
    let back = try JSONDecoder().decode(RuleSet.self, from: JSONEncoder().encode(rules))
    #expect(back == rules)
  }

  @Test func v1AndV2PaymentsAgreeForRandomRuleSetsAndHands() throws {
    var generator = SystemRandomNumberGenerator()
    let seatSets = [abcd, ["A", "B", "C"]]
    for _ in 0..<200 {
      let discarder = Int.random(in: 1...10, using: &generator)
      let others = Int.random(in: 0...10, using: &generator)
      let selfPick = Int.random(in: 1...10, using: &generator)
      let jokerless = Int.random(in: 1...10, using: &generator)
      let bonus = Bool.random(using: &generator)
      let json = """
        {"id":"r","name":"R","discarderMultiplier":\(discarder),"othersOnDiscardMultiplier":\(others),\
        "selfPickMultiplier":\(selfPick),"jokerlessMultiplier":\(jokerless),\
        "jokerlessBonusForNoJokerLines":\(bonus),\
        "money":{"enabled":false,"centsPerPoint":1,"currencySymbol":"$"}}
        """
      let rules = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
      for _ in 0..<5 {
        let seats = seatSets.randomElement(using: &generator)!
        let winner = seats.randomElement(using: &generator)!
        let thrower = Bool.random(using: &generator) ? seats.randomElement(using: &generator) : nil
        let input = MahjongInput(
          winnerID: winner, discarderID: thrower, basePoints: Int.random(in: 1...150, using: &generator),
          jokerless: Bool.random(using: &generator), lineHasNoJokerGroups: Bool.random(using: &generator))
        let expected = v1Payments(
          kind: input, seats: seats, discarder: discarder, others: others, selfPick: selfPick,
          jokerless: jokerless, bonusForNoJokerLines: bonus)
        let actual = Scoring.payments(for: .mahjong(input), seats: seats, dealerID: seats[0], rules: rules)
        #expect(actual == expected)
      }
    }
  }

  @Test func aV1SessionKeepsItsTotals() throws {
    // A v1.0 session as it was written to disk (no rules array, no new MahjongInput keys).
    let json = """
      {"id":"s","createdAt":"1970-01-01T00:00:00Z","seatIDs":["A","B","C","D"],"startDealerIndex":0,\
      "rules":{"id":"standard","name":"Standard","discarderMultiplier":2,"othersOnDiscardMultiplier":1,\
      "selfPickMultiplier":2,"jokerlessMultiplier":2,"jokerlessBonusForNoJokerLines":false,\
      "money":{"enabled":false,"centsPerPoint":1,"currencySymbol":"$"}},\
      "hands":[{"id":"h1","createdAt":"1970-01-01T00:01:40Z","dealerID":"A","payments":{"A":100,"B":-50,"C":-25,"D":-25},\
      "kind":{"mahjong":{"_0":{"winnerID":"A","discarderID":"B","basePoints":25,"jokerless":false,"lineHasNoJokerGroups":false}}}}]}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let session = try decoder.decode(Session.self, from: Data(json.utf8))
    #expect(Scoring.totals(session) == ["A": 100, "B": -50, "C": -25, "D": -25])
    #expect(Scoring.totals(Scoring.withRules(session.rules, session)) == Scoring.totals(session))
  }
}
