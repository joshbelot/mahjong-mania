import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let names = ["a": "Alex", "b": "Bea", "c": "Cy", "d": "Dee"]

private func record(_ kind: HandKind, rules: RuleSet = .standard) -> HandRecord {
  HandRecord(
    id: "h", createdAt: Date(timeIntervalSince1970: 0), dealerID: "a", kind: kind,
    payments: Scoring.payments(for: kind, seats: ["a", "b", "c", "d"], rules: rules))
}

struct GameModelsTests {
  // MARK: Rules summary

  @Test func standardRulesSummary() {
    #expect(RulesSummary.text(.standard) == "Discarder \u{00D7}2 \u{00B7} Self-pick \u{00D7}2 \u{00B7} Jokerless \u{00D7}2")
    #expect(RulesSummary.title(.standard) == "Standard rules")
  }

  @Test func summaryMentionsWhatDiffers() {
    var rules = RuleSet.standard
    rules.othersOnDiscardMultiplier = 2
    rules.jokerlessBonusForNoJokerLines = true
    #expect(
      RulesSummary.text(rules)
        == "Discarder \u{00D7}2 \u{00B7} Self-pick \u{00D7}2 \u{00B7} Jokerless \u{00D7}2 \u{00B7} Others \u{00D7}2 \u{00B7} Bonus on Singles & Pairs"
    )
  }

  @Test func editedStandardRulesAreCalledCustom() {
    var rules = RuleSet.standard
    rules.selfPickMultiplier = 3
    #expect(!RulesSummary.matchesStandard(rules))
    #expect(RulesSummary.title(rules) == "Custom rules")
    rules.id = "mine"
    rules.name = "House rules"
    #expect(RulesSummary.title(rules) == "House rules")
  }

  @Test func moneyDoesNotMakeRulesCustom() {
    var rules = RuleSet.standard
    rules.money = MoneySettings(enabled: true, centsPerPoint: 5, currencySymbol: "$")
    #expect(RulesSummary.matchesStandard(rules))
    #expect(RulesSummary.title(rules) == "Standard rules")
  }

  // MARK: Hand log

  @Test func discardWinRow() {
    let kind = HandKind.mahjong(
      MahjongInput(winnerID: "b", discarderID: "c", lineLabel: "Even Climb", basePoints: 25))
    let entry = HandLogText.entry(for: record(kind), rules: .standard, names: names)
    #expect(entry.title == "Bea \u{2014} Even Climb")
    #expect(entry.meta == "from Cy")
    #expect(entry.points == 100)
  }

  @Test func selfPickJokerlessRowWithoutALabelShowsPoints() {
    let kind = HandKind.mahjong(MahjongInput(winnerID: "b", basePoints: 30, jokerless: true, note: "Wow"))
    let entry = HandLogText.entry(for: record(kind), rules: .standard, names: names)
    #expect(entry.title == "Bea \u{2014} 30 pts")
    #expect(entry.meta == "self-pick \u{00B7} jokerless \u{00B7} Wow")
    #expect(entry.points == 360)
  }

  @Test func jokerlessIsNotShownWhenItDoesNotApply() {
    let kind = HandKind.mahjong(
      MahjongInput(winnerID: "b", basePoints: 50, jokerless: true, lineHasNoJokerGroups: true))
    let entry = HandLogText.entry(for: record(kind), rules: .standard, names: names)
    #expect(entry.meta == "self-pick")
  }

  @Test func wallAndAdjustmentRows() {
    let wall = HandLogText.entry(for: record(.wall(note: nil)), rules: .standard, names: names)
    #expect(wall.title == "Wall game")
    #expect(wall.points == nil)
    let adjustment = HandLogText.entry(
      for: record(.adjustment(fromID: "d", toID: "a", points: 10, note: "Late")), rules: .standard,
      names: names)
    #expect(adjustment.title == "Adjustment")
    #expect(adjustment.meta == "Dee \u{2192} Alex \u{00B7} Late")
    #expect(adjustment.points == 10)
  }

  // MARK: History grouping

  @Test func sessionsAreGroupedByMonthNewestFirst() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    func day(_ month: Int, _ day: Int) -> Date {
      calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? Date()
    }
    func session(_ id: String, _ date: Date) -> Session {
      Session(id: id, createdAt: date, seatIDs: ["a", "b", "c"])
    }
    let groups = HistoryGrouping.byMonth(
      [
        session("sep1", day(9, 3)), session("oct1", day(10, 1)), session("oct2", day(10, 20)),
        session("aug", day(8, 30)),
      ], calendar: calendar)
    #expect(groups.count == 3)
    #expect(groups.map { $0.sessions.map(\.id) } == [["oct2", "oct1"], ["sep1"], ["aug"]])
    #expect(groups[0].month == day(10, 1).startOfMonth(in: calendar))
  }

  @Test func noSessionsMeansNoGroups() {
    #expect(HistoryGrouping.byMonth([]).isEmpty)
  }

  // MARK: Route

  @Test func routesAreHashableForNavigation() {
    let routes: Set<GameRoute> = [.newGame, .history, .players, .session("a"), .session("a"), .player("a")]
    #expect(routes.count == 5)
  }
}

extension Date {
  fileprivate func startOfMonth(in calendar: Calendar) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
  }
}
