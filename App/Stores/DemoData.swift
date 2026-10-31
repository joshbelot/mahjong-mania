import Foundation
import MahjongCore

extension LaunchOptions {
  /// `-UITestEdgeCases` (with `-UITestResetData`): a three-player night with very long and emoji names, a
  /// 200-hand session, an empty user card with a very long name, and a session whose card was deleted.
  static var edgeCases: Bool {
    let arguments = ProcessInfo.processInfo.arguments
    return arguments.contains("-UITestResetData") && arguments.contains("-UITestEdgeCases")
  }

  /// `-UITestDemoData` (with `-UITestResetData`): fill the stores with the demo night, players and practice
  /// progress used for the App Store screenshots. Only the built-in Practice Card is ever used.
  static var demoData: Bool {
    let arguments = ProcessInfo.processInfo.arguments
    return arguments.contains("-UITestResetData") && arguments.contains("-UITestDemoData")
  }
}

extension AppStores {
  /// Four friends, one finished game night from last week, one in progress, and a streak with Unit 1 done.
  /// Dates are fixed so the screenshots never change. Not reachable in normal use.
  func seedDemoData() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    func date(_ day: Int, hour: Int) -> Date {
      calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? Date(timeIntervalSince1970: 0)
    }
    let ids = ["Alex", "Bea", "Cy", "Dee"].enumerated().map { index, name in
      players.add(name: name, id: "demo-\(index)", at: date(1, hour: 12)).id
    }
    var rules = RuleSet.standard
    rules.money = MoneySettings(enabled: true, centsPerPoint: 5, currencySymbol: "$")
    let lines = PracticeCard.card.lines
    func mahjong(_ winner: Int, from discarder: Int?, line: Int, jokerless: Bool = false) -> HandKind {
      let card = lines[line % max(1, lines.count)]
      return .mahjong(
        MahjongInput(
          winnerID: ids[winner], discarderID: discarder.map { ids[$0] }, cardID: PracticeCard.card.id, lineID: card.id,
          lineLabel: card.displayName, basePoints: card.points, jokerless: jokerless, lineConcealed: card.concealed))
    }

    // A finished night, for History and Settle up.
    let past = sessions.start(
      seatIDs: ids, cardID: PracticeCard.card.id, rules: rules, id: "demo-past", at: date(17, hour: 19))
    let pastHands: [HandKind] = [
      mahjong(0, from: 1, line: 3), mahjong(2, from: nil, line: 7), .wall(note: nil), mahjong(1, from: 3, line: 11),
      mahjong(3, from: 0, line: 14, jokerless: true), mahjong(0, from: nil, line: 20), mahjong(2, from: 1, line: 5),
      mahjong(1, from: 0, line: 9),
    ]
    for (n, hand) in pastHands.enumerated() { sessions.addHand(hand, to: past.id, id: "past-\(n)", at: date(17, hour: 19 + n / 4)) }
    sessions.end(sessionID: past.id, at: date(17, hour: 23))

    // Tonight's game, in progress.
    let tonight = sessions.start(
      seatIDs: ids, cardID: PracticeCard.card.id, rules: rules, id: "demo-tonight", at: date(30, hour: 19))
    let hands: [HandKind] = [
      mahjong(1, from: 2, line: 2), mahjong(0, from: nil, line: 6, jokerless: true), .wall(note: nil),
      mahjong(3, from: 1, line: 12), mahjong(2, from: 0, line: 17),
    ]
    for (n, hand) in hands.enumerated() { sessions.addHand(hand, to: tonight.id, id: "tonight-\(n)", at: date(30, hour: 19 + n / 3)) }

    // Practice: Unit 1 done, Unit 2 started, a six-day streak, 520 XP.
    practice.update { progress in
      progress.placement = .new
      progress.goalChosen = true
      progress.dailyGoal = .regular
      progress.xp = 520
      progress.levelsCelebrated = 3
      for (id, stars) in [("u1l1", 3), ("u1l2", 3), ("u1l3", 2), ("u2l1", 3)] {
        var lesson = LessonProgress()
        lesson.stars = stars
        lesson.plays = 1
        lesson.bestAccuracy = stars == 3 ? 1 : 0.88
        progress.lessons[id] = lesson
      }
      var unit = UnitProgress()
      unit.checkpointPassed = true
      progress.units[1] = unit
    }
    settings.update { $0.onboardingDone = true }
  }
}

extension AppStores {
  /// Awkward data for the layout and edge-case sweeps (SPEC §19.4 steps 4 and 5).
  func seedEdgeCases() {
    let names = [
      "Bartholomew Maximilian Featherstonehaugh-Worthington the Third", "\u{1F600}\u{1F389} Sunny \u{1F9E1}", "Zo\u{00EB} \u{05E9}\u{05DC}\u{05D5}\u{05DD}",
    ]
    let ids = names.enumerated().map { players.add(name: $1, id: "edge-\($0)").id }
    var rules = RuleSet.standard
    rules.money = MoneySettings(enabled: true, centsPerPoint: 100, currencySymbol: "$")
    let lines = PracticeCard.card.lines
    // A card with a very long name and no valid hands, used by an earlier night and then deleted.
    let longName = "The Wednesday Night Mahjong Club Autumn Edition with Everyone's Favourite Hands (draft number 7)"
    let gone = cards.createCard(name: longName, text: "this is not a hand\nneither is this")
    let earlier = sessions.start(seatIDs: ids, cardID: gone.id, rules: rules, id: "edge-earlier", at: Date(timeIntervalSince1970: 1_700_000_000))
    sessions.addHand(.wall(note: nil), to: earlier.id)
    sessions.end(sessionID: earlier.id, at: Date(timeIntervalSince1970: 1_700_003_600))
    cards.delete(id: gone.id)
    _ = cards.createCard(name: longName + " (empty copy)", text: "")

    let long = sessions.start(seatIDs: ids, cardID: PracticeCard.card.id, rules: rules, id: "edge-long")
    for n in 0..<200 {
      let winner = n % 3
      let line = lines[n % max(1, lines.count)]
      let kind: HandKind = n % 11 == 5
        ? .wall(note: String(repeating: "A long note ", count: 12))
        : .mahjong(
          MahjongInput(
            winnerID: ids[winner], discarderID: n % 4 == 0 ? nil : ids[(winner + 1) % 3], cardID: PracticeCard.card.id,
            lineID: line.id, lineLabel: line.displayName, basePoints: line.points, jokerless: n % 7 == 0))
      sessions.addHand(kind, to: long.id, id: "edge-\(n)", at: Date(timeIntervalSince1970: 1_800_000_000 + Double(n)))
    }
    settings.update { $0.onboardingDone = true }
  }
}
