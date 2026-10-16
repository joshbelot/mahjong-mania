import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)

/// Files exactly as 1.0 wrote them: rule sets with four multipliers and no `rules` array, hands
/// without the 1.1 line fields. They must load with the same totals (SPEC §17.4, Phase 15).
@MainActor
struct V1FixtureTests {
  private static let rulesJSON = """
    {"id":"mine","name":"Grandma's","discarderMultiplier":3,"othersOnDiscardMultiplier":2,\
    "selfPickMultiplier":4,"jokerlessMultiplier":3,"jokerlessBonusForNoJokerLines":true,\
    "money":{"enabled":true,"centsPerPoint":5,"currencySymbol":"$"}}
    """

  private static let standardRulesJSON = """
    {"id":"standard","name":"Standard","discarderMultiplier":2,"othersOnDiscardMultiplier":1,\
    "selfPickMultiplier":2,"jokerlessMultiplier":2,"jokerlessBonusForNoJokerLines":false,\
    "money":{"enabled":false,"centsPerPoint":1,"currencySymbol":"$"}}
    """

  /// Four hands under the standard rules: a discard win, a self-pick, a jokerless discard win, a wall game.
  private static let sessionsJSON = """
    {"version":1,"activeSessionID":"s1","sessions":[{"id":"s1","createdAt":"2026-10-12T18:00:00Z",\
    "seatIDs":["A","B","C","D"],"startDealerIndex":0,"cardID":"practice-v1","rules":\(standardRulesJSON),\
    "hands":[\
    {"id":"h1","createdAt":"2026-10-12T18:05:00Z","dealerID":"A","payments":{"A":100,"B":-50,"C":-25,"D":-25},\
    "kind":{"mahjong":{"_0":{"winnerID":"A","discarderID":"B","basePoints":25,"jokerless":false,"lineHasNoJokerGroups":false}}}},\
    {"id":"h2","createdAt":"2026-10-12T18:10:00Z","dealerID":"B","payments":{"A":-60,"B":180,"C":-60,"D":-60},\
    "kind":{"mahjong":{"_0":{"winnerID":"B","basePoints":30,"jokerless":false,"lineHasNoJokerGroups":false,"lineLabel":"Evens #1"}}}},\
    {"id":"h3","createdAt":"2026-10-12T18:15:00Z","dealerID":"C","payments":{"A":-50,"B":-50,"C":200,"D":-100},\
    "kind":{"mahjong":{"_0":{"winnerID":"C","discarderID":"D","basePoints":25,"jokerless":true,"lineHasNoJokerGroups":false}}}},\
    {"id":"h4","createdAt":"2026-10-12T18:20:00Z","dealerID":"D","payments":{"A":0,"B":0,"C":0,"D":0},\
    "kind":{"wall":{"note":null}}}]}]}
    """

  private func write(_ json: String, as name: String, in directory: URL) throws {
    try json.write(to: directory.appendingPathComponent("\(name).json"), atomically: true, encoding: .utf8)
  }

  @Test func a10SessionLoadsWithIdenticalTotals() throws {
    let directory = makeTempDirectory()
    try write(Self.sessionsJSON, as: "sessions", in: directory)
    let store = SessionsStore(directory: directory, persistDelay: fast)
    let session = try #require(store.session(id: "s1"))
    // Totals straight from the stored payments:
    #expect(Scoring.totals(session)["A"] == 100 - 60 - 50)
    #expect(Scoring.totals(session)["B"] == -50 + 180 - 50)
    #expect(Scoring.totals(session)["C"] == -25 - 60 + 200)
    #expect(Scoring.totals(session)["D"] == -25 - 60 - 100)
    // Recomputing every hand from the loaded (migrated) rules gives the same numbers.
    let recomputed = Scoring.withRules(session.rules, session)
    #expect(Scoring.totals(recomputed) == Scoring.totals(session))
    #expect(recomputed.hands.map(\.payments) == session.hands.map(\.payments))
    #expect(session.rules.rules.map(\.id) == RuleCatalog.builtIns.map(\.id))
  }

  @Test func a10SessionIsSavedInTheNewShapeAndReadsBackTheSame() throws {
    let directory = makeTempDirectory()
    try write(Self.sessionsJSON, as: "sessions", in: directory)
    let store = SessionsStore(directory: directory, persistDelay: fast)
    let before = try #require(store.session(id: "s1"))
    store.flush()
    let saved = try String(contentsOf: directory.appendingPathComponent("sessions.json"), encoding: .utf8)
    #expect(saved.contains("\"rules\""))
    let reloaded = SessionsStore(directory: directory, persistDelay: fast)
    #expect(reloaded.session(id: "s1") == before)
  }

  @Test func a10SettingsKeepTheirRulesAndSavedRuleBooks() throws {
    let directory = makeTempDirectory()
    let json = """
      {"version":1,"assistLevel":"coach","theme":"dark","haptics":true,"keepAwake":true,"tileSort":"suit",\
      "defaultRules":\(Self.rulesJSON),"savedRules":[\(Self.standardRulesJSON),\(Self.rulesJSON)],\
      "onboardingDone":true,"activeCardID":"practice-v1","cardNoticeSeen":true,\
      "bestStreaks":{"pickAHand":2,"charleston":1}}
      """
    try write(json, as: "settings", in: directory)
    let store = SettingsStore(directory: directory, persistDelay: fast)
    let rules = store.settings.defaultRules
    #expect(rules.name == "Grandma's")
    #expect(rules.discarderMultiplier == 3)
    #expect(rules.othersOnDiscardMultiplier == 2)
    #expect(rules.selfPickMultiplier == 4)
    #expect(rules.jokerlessMultiplier == 3)
    #expect(rules.jokerlessBonusForNoJokerLines)
    #expect(rules.money == MoneySettings(enabled: true, centsPerPoint: 5, currencySymbol: "$"))
    #expect(store.settings.savedRules.count == 2)
    #expect(store.settings.savedRules[0] == .standard.renamed("Standard", id: "standard"))
    // The old rules and the new defaults pay the same on a hand.
    let hand = MahjongInput(winnerID: "A", discarderID: "B", basePoints: 25, jokerless: true)
    let paid = Scoring.payments(
      for: .mahjong(hand), seats: ["A", "B", "C", "D"], dealerID: "A", rules: rules)
    #expect(paid == ["A": 25 * 3 * 3 + 2 * 25 * 3 * 2, "B": -(25 * 3 * 3), "C": -(25 * 2 * 3), "D": -(25 * 2 * 3)])
  }

  @Test func rulesWithMissingBuiltInsGainThemOnLoad() throws {
    let directory = makeTempDirectory()
    let json = """
      {"version":1,"defaultRules":{"id":"x","name":"X","rules":[{"id":"pay.selfPick","isEnabled":true,"multiple":3}],\
      "money":{"enabled":false,"centsPerPoint":1,"currencySymbol":"$"}}}
      """
    try write(json, as: "settings", in: directory)
    let store = SettingsStore(directory: directory, persistDelay: fast)
    #expect(store.settings.defaultRules.rules.map(\.id) == RuleCatalog.builtIns.map(\.id))
    #expect(store.settings.defaultRules.selfPickMultiplier == 3)
  }
}

private extension RuleSet {
  func renamed(_ name: String, id: String) -> RuleSet {
    var copy = self
    copy.name = name
    copy.id = id
    return copy
  }
}
