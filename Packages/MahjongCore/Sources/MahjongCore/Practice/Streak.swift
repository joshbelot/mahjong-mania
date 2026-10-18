import Foundation

public enum DailyGoal: String, Codable, CaseIterable, Sendable {
  case casual, regular, serious

  public var lessons: Int {
    switch self {
    case .casual: return 1
    case .regular: return 2
    case .serious: return 4
    }
  }

  public var title: String {
    switch self {
    case .casual: return "Casual"
    case .regular: return "Regular"
    case .serious: return "Serious"
    }
  }
}

public enum StreakEvent: Hashable, Sendable {
  /// A missed day was covered by a freeze; the streak is kept at `streak`.
  case freezeUsed(day: LocalDay, streak: Int)
  case streakLost(previous: Int, daysPlayed: Int)
  case streakGrew(to: Int)
  case freezeEarned(held: Int)
  case milestone(Int)
  case goalMet
}

/// The streak, kept as plain whole-day arithmetic on `LocalDay`s (SPEC §18.6).
public struct StreakState: Hashable, Codable, Sendable {
  public var current = 0
  public var longest = 0
  public var freezes = 0
  /// The last day the goal was met, or the last missed day a freeze covered.
  public var lastDay: LocalDay?
  /// The last day the goal was met (a frozen day doesn't count).
  public var lastGoalDay: LocalDay?
  public var lastPlayedDay: LocalDay?
  public var daysPlayed = 0

  public init() {}
}

public enum StreakLogic {
  public static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]
  public static let freezeEvery = 7
  public static let maxFreezes = 2

  /// Closes every day before `today` that went by without the goal: each missed day uses a freeze if you hold enough for all of them,
  /// otherwise the streak resets (and the freezes are kept). Today itself is still open. Going backwards (a trip west) changes nothing.
  @discardableResult
  public static func settle(_ state: inout StreakState, today: LocalDay) -> [StreakEvent] {
    guard let last = state.lastDay, state.current > 0 else { return [] }
    let missed = today.days(since: last) - 1
    guard missed > 0 else { return [] }
    var events: [StreakEvent] = []
    if missed > state.freezes {
      // Not enough freezes for every missed day: the streak ends and the freezes are kept for next time.
      events.append(.streakLost(previous: state.current, daysPlayed: state.daysPlayed))
      state.current = 0
      return events
    }
    for step in 1...missed {
      state.freezes -= 1
      let day = last.adding(days: step)
      state.lastDay = day
      events.append(.freezeUsed(day: day, streak: state.current))
    }
    return events
  }

  /// Notes a finished lesson on `day`; `lessonsToday` is the day's count including this one.
  @discardableResult
  public static func recordLesson(
    _ state: inout StreakState, day: LocalDay, lessonsToday: Int, goal: DailyGoal
  ) -> [StreakEvent] {
    var events = settle(&state, today: day)
    if state.lastPlayedDay != day {
      state.daysPlayed += 1
      state.lastPlayedDay = day
    }
    guard lessonsToday >= goal.lessons else { return events }
    if let goalDay = state.lastGoalDay, day <= goalDay { return events }

    state.lastGoalDay = day
    state.lastDay = day
    state.current += 1
    state.longest = max(state.longest, state.current)
    events.append(.goalMet)
    events.append(.streakGrew(to: state.current))
    if state.current % freezeEvery == 0 && state.freezes < maxFreezes {
      state.freezes += 1
      events.append(.freezeEarned(held: state.freezes))
    }
    if milestones.contains(state.current) { events.append(.milestone(state.current)) }
    return events
  }

  /// What to show on `today` without changing anything: the streak after closing the days gone by.
  public static func display(_ state: StreakState, today: LocalDay) -> StreakState {
    var copy = state
    settle(&copy, today: today)
    return copy
  }

  /// Is today's goal already met?
  public static func goalMet(_ state: StreakState, today: LocalDay) -> Bool {
    state.lastGoalDay == today
  }

  /// Replays a list of days (`goalMet` true = the goal was met that day, false = played short of it) to
  /// the state on `today`. Used to rebuild a streak and to test the rules over long histories.
  public static func replay(
    _ facts: [(day: LocalDay, goalMet: Bool)], goal: DailyGoal = .casual, today: LocalDay
  ) -> StreakState {
    var state = StreakState()
    for fact in facts.sorted(by: { $0.day < $1.day }) {
      recordLesson(&state, day: fact.day, lessonsToday: fact.goalMet ? goal.lessons : max(0, goal.lessons - 1), goal: goal)
    }
    settle(&state, today: today)
    return state
  }

  /// Friendly copy after a break (never shaming).
  public static func brokenMessage(daysPlayed: Int) -> String {
    "New streak, same skills. You've played \(daysPlayed) \(daysPlayed == 1 ? "day" : "days") in total."
  }

  public static func freezeMessage(streak: Int) -> String {
    "Your streak freeze kept your \(streak)-day streak safe."
  }
}
