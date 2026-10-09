import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let names = ["a": "Alex", "b": "Bea", "c": "Cy", "d": "Dee"]
private let night = Date(timeIntervalSince1970: 1_791_000_000)

private func rules(money: Bool) -> RuleSet {
  var rules = RuleSet.standard
  rules.money = MoneySettings(enabled: money, centsPerPoint: 1, currencySymbol: "$")
  return rules
}

private func add(_ session: Session, _ kind: HandKind, _ id: String) -> Session {
  Scoring.adding(kind, to: session, id: id, at: night)
}

/// Alex +180, Bea +260, Cy -245, Dee -195.
private func playedSession(money: Bool = true) -> Session {
  var session = Session(id: "s", createdAt: night, seatIDs: ["a", "b", "c", "d"], rules: rules(money: money))
  session = add(
    session,
    .mahjong(MahjongInput(winnerID: "a", discarderID: "b", lineLabel: "Even Climb", basePoints: 25)), "h1")
  session = add(
    session, .mahjong(MahjongInput(winnerID: "b", basePoints: 30, jokerless: true)), "h2")
  session = add(
    session, .mahjong(MahjongInput(winnerID: "a", discarderID: "c", basePoints: 50)), "h3")
  return session
}

struct SummaryModelTests {
  @Test func standingsAreSortedWithRanks() {
    let model = SummaryModel(session: playedSession())
    #expect(model.standings.map(\.id) == ["b", "a", "d", "c"])
    #expect(model.standings.map(\.points) == [260, 180, -195, -245])
    #expect(model.standings.map(\.rank) == [1, 2, 3, 4])
    #expect(model.standings.map(\.cents) == [260, 180, -195, -245])
    #expect(model.leaderIDs == ["b"])
  }

  @Test func tiesShareARankAndSeatOrderBreaksThem() {
    var session = Session(id: "s", createdAt: night, seatIDs: ["a", "b", "c", "d"], rules: rules(money: false))
    session = add(session, .adjustment(fromID: "c", toID: "a", points: 10, note: nil), "h1")
    session = add(session, .adjustment(fromID: "d", toID: "b", points: 10, note: nil), "h2")
    let model = SummaryModel(session: session)
    #expect(model.standings.map(\.id) == ["a", "b", "c", "d"])
    #expect(model.standings.map(\.rank) == [1, 1, 3, 3])
    #expect(model.leaderIDs == ["a", "b"])
    #expect(model.winnerText(names: names) == "Tied: Alex & Bea")
  }

  @Test func nobodyLeadsBeforeAnyHandIsPlayed() {
    let session = Session(id: "s", createdAt: night, seatIDs: ["a", "b", "c"], rules: rules(money: true))
    let model = SummaryModel(session: session)
    #expect(model.leaderIDs.isEmpty)
    #expect(model.transfers.isEmpty)
    #expect(model.highlights(names: names).isEmpty)
    #expect(model.winnerText(names: names) == "No winner")
  }

  @Test func highlights() {
    let model = SummaryModel(session: playedSession())
    #expect(
      model.highlights(names: names) == [
        .init(title: "Biggest hand", value: "Bea \u{00B7} 30 base \u{00B7} 360 pts"),
        .init(title: "Most wins", value: "Alex (2 wins)"),
        .init(title: "Most jokerless", value: "Bea (1 jokerless win)"),
      ])
    #expect(model.winnerText(names: names) == "Won by Bea")
  }

  @Test func biggestHandUsesTheLineLabelWhenThereIsOne() {
    var session = Session(id: "s", createdAt: night, seatIDs: ["a", "b", "c", "d"], rules: rules(money: false))
    session = add(
      session,
      .mahjong(MahjongInput(winnerID: "c", discarderID: "a", lineLabel: "Even Climb", basePoints: 25)), "h1")
    let highlights = SummaryModel(session: session).highlights(names: names)
    #expect(
      highlights.first
        == SummaryModel.Highlight(title: "Biggest hand", value: "Cy \u{00B7} Even Climb \u{00B7} 100 pts"))
    #expect(!highlights.contains { $0.title == "Most jokerless" })
  }

  @Test func tiedMostWinsListsEveryone() {
    var session = Session(id: "s", createdAt: night, seatIDs: ["a", "b", "c", "d"], rules: rules(money: false))
    session = add(session, .mahjong(MahjongInput(winnerID: "a", basePoints: 25)), "h1")
    session = add(session, .mahjong(MahjongInput(winnerID: "c", basePoints: 25)), "h2")
    let wins = SummaryModel(session: session).highlights(names: names).first { $0.title == "Most wins" }
    #expect(wins?.value == "Alex & Cy (1 win each)")
  }

  @Test func settleUpLines() {
    let model = SummaryModel(session: playedSession())
    #expect(
      model.settleLines(names: names) == [
        "Cy pays Bea $2.45", "Dee pays Alex $1.80", "Dee pays Bea $0.15",
      ])
  }

  @Test func settleUpUsesCentsPerPoint() {
    var session = playedSession()
    session.rules.money.centsPerPoint = 5
    let lines = SummaryModel(session: session).settleLines(names: names)
    #expect(lines.first == "Cy pays Bea $12.25")
  }

  @Test func noSettleUpWithoutMoney() {
    let model = SummaryModel(session: playedSession(money: false))
    #expect(model.transfers.isEmpty)
    #expect(model.settleLines(names: names).isEmpty)
  }

  @Test func shareTextWithMoney() {
    let text = SummaryModel(session: playedSession()).shareText(names: names, dateText: "Oct 8, 2026")
    let expected = [
      "Mahjong game night",
      "Oct 8, 2026",
      "",
      "1. Bea +260 pts (+$2.60)",
      "2. Alex +180 pts (+$1.80)",
      "3. Dee \u{2212}195 pts (\u{2212}$1.95)",
      "4. Cy \u{2212}245 pts (\u{2212}$2.45)",
      "",
      "Settle up",
      "Cy pays Bea $2.45",
      "Dee pays Alex $1.80",
      "Dee pays Bea $0.15",
      "",
      "Kept with Mahjong Mania",
    ].joined(separator: "\n")
    #expect(text == expected)
  }

  @Test func shareTextWithoutMoneyHasNoSettleUp() {
    let text = SummaryModel(session: playedSession(money: false)).shareText(
      names: names, dateText: "Oct 8, 2026")
    #expect(!text.contains("Settle up"))
    #expect(!text.contains("$"))
    #expect(text.contains("1. Bea +260 pts"))
    #expect(text.hasSuffix("Kept with Mahjong Mania"))
  }

  @Test func signedFormatting() {
    #expect(SummaryModel.signed(5) == "+5")
    #expect(SummaryModel.signed(-5) == "\u{2212}5")
    #expect(SummaryModel.signed(0) == "0")
  }
}
