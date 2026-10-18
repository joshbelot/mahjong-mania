import Foundation
import MahjongCore

/// Launch arguments used by UI tests and simulator checks for the Practice tab.
///
/// - `-UITestToday 2026-11-02`: pretend this is today's date (Daily Deal, streaks, review).
/// - `-UITestHour 7`: pretend it is this local hour.
/// - `-UITestPracticeSeed 5`: every lesson, checkpoint and review uses this seed, so its questions are known.
/// - `-UITestRevealAnswers`: multiple-choice buttons carry the accessibility value "correct" or "wrong".
/// - `-UITestPlayNode u6l2`: open this node's lesson as soon as the Practice tab appears (simulator checks).
/// - `-UITestPlacement new|basics|regular`: start with this placement already chosen (with `-UITestResetData`).
extension LaunchOptions {
  static func practiceClock(arguments: [String] = ProcessInfo.processInfo.arguments) -> PracticeClock {
    guard arguments.contains("-UITestResetData") || arguments.contains("-UITestShowOnboarding") else { return .system }
    let day = value(after: "-UITestToday", in: arguments).flatMap { LocalDay($0) }
    let hour = value(after: "-UITestHour", in: arguments).flatMap { Int($0) }
    guard day != nil || hour != nil else { return .system }
    if let day { return .fixed(day, hour: hour ?? 12) }
    let hourOnly = hour ?? 12
    return PracticeClock {
      (LocalDay(Date(), calendar: .current), hourOnly)
    }
  }

  static func practiceSeed(arguments: [String] = ProcessInfo.processInfo.arguments) -> UInt64? {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestPracticeSeed", in: arguments),
      let seed = UInt64(text)
    else { return nil }
    return seed
  }

  static var revealAnswers: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITestRevealAnswers")
  }

  static func placement(arguments: [String] = ProcessInfo.processInfo.arguments) -> Placement? {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestPlacement", in: arguments) else {
      return nil
    }
    return Placement(rawValue: text)
  }
}

extension LaunchOptions {
  static func playNode(arguments: [String] = ProcessInfo.processInfo.arguments) -> LessonSpec? {
    guard arguments.contains("-UITestResetData"), let id = value(after: "-UITestPlayNode", in: arguments) else { return nil }
    return Curriculum.node(id: id)
  }
}

/// - `-UITestDayLog 2026-10-29,2026-10-30`: days on which the daily goal was already met (with `-UITestResetData`).
/// - `-UITestFreezes 1`: start holding this many streak freezes.
/// - `-UITestDailyGoal casual|regular|serious`: start with this goal chosen.
extension LaunchOptions {
  static func dayLog(arguments: [String] = ProcessInfo.processInfo.arguments) -> [LocalDay] {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestDayLog", in: arguments) else { return [] }
    return text.split(separator: ",").compactMap { LocalDay(String($0)) }.sorted()
  }

  static func freezes(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int? {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestFreezes", in: arguments) else { return nil }
    return Int(text)
  }

  static func dailyGoal(arguments: [String] = ProcessInfo.processInfo.arguments) -> DailyGoal? {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestDailyGoal", in: arguments) else { return nil }
    return DailyGoal(rawValue: text)
  }
}

extension LaunchOptions {
  /// `-UITestSpeedNoTimer`: switch "No timer in Speed Round" on (with `-UITestResetData`).
  static var speedNoTimer: Bool {
    let arguments = ProcessInfo.processInfo.arguments
    return arguments.contains("-UITestResetData") && arguments.contains("-UITestSpeedNoTimer")
  }
}

extension LaunchOptions {
  /// `-UITestReviewItems 3`: start with this many questions waiting in the review queue.
  static func reviewItems(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int? {
    guard arguments.contains("-UITestResetData"), let text = value(after: "-UITestReviewItems", in: arguments) else { return nil }
    return Int(text)
  }
}
