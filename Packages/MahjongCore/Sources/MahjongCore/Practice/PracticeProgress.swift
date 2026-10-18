import Foundation

public enum Placement: String, Codable, Sendable {
  case new, basics, regular

  /// Units marked "tested out" at the start.
  public var testedOutUnits: ClosedRange<Int>? {
    switch self {
    case .new: return nil
    case .basics: return 1...3
    case .regular: return 1...6
    }
  }
}

public struct LessonProgress: Hashable, Codable, Sendable {
  public var stars = 0
  public var gold = false
  public var testedOut = false
  public var bestAccuracy = 0.0
  public var plays = 0
  public init() {}
}

public struct UnitProgress: Hashable, Codable, Sendable {
  public var checkpointPassed = false
  public var gold = false
  public var testedOut = false
  public init() {}
}

public struct DayRecord: Hashable, Codable, Sendable {
  public var lessons = 0
  public var goalMet = false
  public init(lessons: Int = 0, goalMet: Bool = false) {
    self.lessons = lessons
    self.goalMet = goalMet
  }
}

public struct DealRecord: Hashable, Codable, Sendable {
  public var pick: DailyDeal.PickMark
  public var pickDistance: Int
  public var pass: [DailyDeal.PassMark]
  public var completed = true
  public init(pick: DailyDeal.PickMark, pickDistance: Int, pass: [DailyDeal.PassMark]) {
    self.pick = pick
    self.pickDistance = pickDistance
    self.pass = pass
  }
}

public enum NodeStatus: Equatable, Sendable {
  case locked, next, done, testedOut
}

public struct PathNode: Identifiable, Equatable, Sendable {
  public var spec: LessonSpec
  public var status: NodeStatus
  public var stars: Int
  public var gold: Bool
  public var id: String { spec.id }
}

/// What a finished play looked like.
public struct PlayResult: Sendable {
  public var nodeID: String
  public var gold: Bool
  /// A checkpoint played as "Test out" (needs 8 of 10 instead of 7).
  public var testOut: Bool
  public var records: [AnswerRecord]
  public var seconds: Int
  public var day: LocalDay
  /// Local hour of the day (0...23) when it ended.
  public var hour: Int

  public init(
    nodeID: String, gold: Bool = false, testOut: Bool = false, records: [AnswerRecord], seconds: Int = 0,
    day: LocalDay, hour: Int = 12
  ) {
    self.nodeID = nodeID
    self.gold = gold
    self.testOut = testOut
    self.records = records
    self.seconds = seconds
    self.day = day
    self.hour = hour
  }
}

public struct XPBreakdown: Equatable, Sendable {
  public var answers = 0
  public var combo = 0
  public var finished = 0
  public var stars = 0
  public var checkpoint = 0
  public var gold = 0
  public var badges = 0
  public var total: Int { answers + combo + finished + stars + checkpoint + gold + badges }
}

public struct PlayOutcome: Sendable {
  public var node: LessonSpec?
  public var xp = XPBreakdown()
  public var stars = 0
  public var previousStars = 0
  public var accuracy = 0.0
  /// Checkpoint passed / gold passed; true for ordinary lessons.
  public var passed = true
  public var bestCombo = 0
  public var levelUp: Levels.Position?
  public var newBadges: [BadgeID] = []
  public var streakEvents: [StreakEvent] = []
  public var lessonsToday = 0
  public var goalJustMet = false
  public var unitFinished: Int?
  public var unitGold: Int?
  public var seconds = 0
  public var improvedStars: Bool { stars > previousStars }
}

/// Everything the Practice game remembers (SPEC §18.9) and the rules that change it. Pure value type:
/// the app only stores and loads it.
public struct PracticeProgress: Codable, Equatable, Sendable {
  public var placement: Placement?
  public var lessons: [String: LessonProgress] = [:]
  public var units: [Int: UnitProgress] = [:]
  public var xp = 0
  /// The highest level whose celebration has been shown.
  public var levelsCelebrated = 1
  /// Keyed by `LocalDay.description`; the last 400 days are kept.
  public var dayLog: [String: DayRecord] = [:]
  public var streak = StreakState()
  public var dailyGoal = DailyGoal.casual
  /// Has the player picked a goal (asked once, after the first lesson)?
  public var goalChosen = false
  public var dailyDeals: [String: DealRecord] = [:]
  public var speedBest = 0
  public var badges: [String: LocalDay] = [:]
  public var reviewQueue = ReviewQueue()
  public var counters = PracticeCounters()
  public var freePlay = FreePlayBests()

  public init() {}

  public struct FreePlayBests: Codable, Equatable, Sendable {
    public var pickStreakBest = 0
    public var charlestonStreakBest = 0
    public init() {}
  }

  private enum CodingKeys: String, CodingKey {
    case placement, lessons, units, xp, levelsCelebrated, dayLog, streak, dailyGoal, goalChosen, dailyDeals,
      speedBest, badges, reviewQueue, counters, freePlay
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    placement = try c.decodeIfPresent(Placement.self, forKey: .placement)
    lessons = try c.decodeIfPresent([String: LessonProgress].self, forKey: .lessons) ?? [:]
    units = try c.decodeIfPresent([Int: UnitProgress].self, forKey: .units) ?? [:]
    xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
    levelsCelebrated = try c.decodeIfPresent(Int.self, forKey: .levelsCelebrated) ?? 1
    dayLog = try c.decodeIfPresent([String: DayRecord].self, forKey: .dayLog) ?? [:]
    streak = try c.decodeIfPresent(StreakState.self, forKey: .streak) ?? StreakState()
    dailyGoal = try c.decodeIfPresent(DailyGoal.self, forKey: .dailyGoal) ?? .casual
    goalChosen = try c.decodeIfPresent(Bool.self, forKey: .goalChosen) ?? false
    dailyDeals = try c.decodeIfPresent([String: DealRecord].self, forKey: .dailyDeals) ?? [:]
    speedBest = try c.decodeIfPresent(Int.self, forKey: .speedBest) ?? 0
    badges = try c.decodeIfPresent([String: LocalDay].self, forKey: .badges) ?? [:]
    reviewQueue = try c.decodeIfPresent(ReviewQueue.self, forKey: .reviewQueue) ?? ReviewQueue()
    counters = try c.decodeIfPresent(PracticeCounters.self, forKey: .counters) ?? PracticeCounters()
    freePlay = try c.decodeIfPresent(FreePlayBests.self, forKey: .freePlay) ?? FreePlayBests()
  }

  public var level: Levels.Position { Levels.position(totalXP: xp) }

  // MARK: Placement and path

  public mutating func applyPlacement(_ choice: Placement) {
    placement = choice
    if let range = choice.testedOutUnits { markTestedOut(upTo: range.upperBound) }
  }

  mutating func markTestedOut(upTo unit: Int) {
    for number in 1...max(1, unit) {
      guard let spec = Curriculum.unit(number) else { continue }
      var progress = units[number] ?? UnitProgress()
      progress.testedOut = true
      units[number] = progress
      for node in spec.nodes where node.kind == .lesson {
        if (lessons[node.id]?.stars ?? 0) == 0 {
          var lesson = lessons[node.id] ?? LessonProgress()
          lesson.testedOut = true
          lessons[node.id] = lesson
        }
      }
    }
  }

  func isDone(_ node: LessonSpec) -> Bool {
    switch node.kind {
    case .lesson: return (lessons[node.id]?.stars ?? 0) >= 1
    case .review: return (lessons[node.id]?.plays ?? 0) >= 1
    case .checkpoint: return units[node.unit]?.checkpointPassed ?? false
    }
  }

  public func nodes() -> [PathNode] {
    var foundNext = false
    return Curriculum.allNodes.map { spec in
      let status: NodeStatus
      if isDone(spec) {
        status = .done
      } else if units[spec.unit]?.testedOut == true {
        status = .testedOut
      } else if !foundNext {
        status = .next
        foundNext = true
      } else {
        status = .locked
      }
      return PathNode(
        spec: spec, status: status, stars: lessons[spec.id]?.stars ?? 0, gold: lessons[spec.id]?.gold ?? false)
    }
  }

  public var nextNode: PathNode? { nodes().first { $0.status == .next } }

  public func isUnitFinished(_ number: Int) -> Bool {
    guard let spec = Curriculum.unit(number) else { return false }
    return isDone(spec.checkpoint) || units[number]?.testedOut == true
  }

  /// Units that are open to play (finished, tested out, or the one holding the next node).
  public func isUnitOpen(_ number: Int) -> Bool {
    if isUnitFinished(number) { return true }
    return nextNode?.spec.unit == number
  }

  /// "Test out" is offered for any unit that isn't finished.
  public func canTestOut(_ number: Int) -> Bool { !isUnitFinished(number) }

  /// "Go gold" appears when every lesson of the unit has three stars.
  public func goldAvailable(_ number: Int) -> Bool {
    guard let spec = Curriculum.unit(number), units[number]?.gold != true else { return false }
    return spec.lessons.allSatisfy { (lessons[$0.id]?.stars ?? 0) == 3 }
  }

  public var finishedUnits: Set<Int> { Set((1...10).filter(isUnitFinished)) }
  public var goldUnits: Set<Int> { Set(units.filter { $0.value.gold }.keys) }

  // MARK: Days

  public func lessonsPlayed(on day: LocalDay) -> Int { dayLog[day.description]?.lessons ?? 0 }

  public func goalMet(on day: LocalDay) -> Bool { dayLog[day.description]?.goalMet ?? false }

  /// Closes the days gone by; call when the app opens. Returns what happened to the streak.
  @discardableResult
  public mutating func openDay(_ today: LocalDay) -> [StreakEvent] {
    StreakLogic.settle(&streak, today: today)
  }

  // MARK: Applying a play

  mutating func noteActivity(on day: LocalDay, hour: Int) -> (events: [StreakEvent], lessonsToday: Int, goalJustMet: Bool) {
    var record = dayLog[day.description] ?? DayRecord()
    record.lessons += 1
    let wasMet = record.goalMet
    let events = StreakLogic.recordLesson(&streak, day: day, lessonsToday: record.lessons, goal: dailyGoal)
    if record.lessons >= dailyGoal.lessons { record.goalMet = true }
    dayLog[day.description] = record
    if dayLog.count > 400 {
      let cutoff = day.adding(days: -400)
      dayLog = dayLog.filter { (LocalDay($0.key) ?? day) > cutoff }
    }
    if hour < 8 { counters.earlyLessons += 1 }
    if hour >= 22 { counters.nightLessons += 1 }
    return (events, record.lessons, record.goalMet && !wasMet)
  }

  /// Adds XP and reports a new level reached (once per level).
  mutating func addXP(_ amount: Int) -> Levels.Position? {
    xp += amount
    let position = Levels.position(totalXP: xp)
    guard position.level > levelsCelebrated else { return nil }
    levelsCelebrated = position.level
    return position
  }

  /// Awards badges earned by the current state; returns them and the XP they paid.
  mutating func awardBadges(on day: LocalDay) -> [BadgeID] {
    counters.threeStarLessons = lessons.values.filter { $0.stars == 3 }.count
    let earned = Badges.earned(
      counters: counters, finishedUnits: finishedUnits, goldUnits: goldUnits, streak: streak)
    let fresh = BadgeID.allCases.filter { earned.contains($0) && badges[$0.rawValue] == nil }
    for badge in fresh { badges[badge.rawValue] = day }
    return fresh
  }

  /// Applies a finished lesson, review, checkpoint or gold lesson.
  public mutating func apply(_ result: PlayResult) -> PlayOutcome? {
    guard let node = Curriculum.node(id: result.nodeID) else { return nil }
    var outcome = PlayOutcome(node: node)
    let records = result.records
    outcome.seconds = result.seconds
    outcome.accuracy = LessonScoring.firstTryAccuracy(records)
    let combo = LessonScoring.combo(records)
    outcome.bestCombo = combo.best
    counters.bestCombo = max(counters.bestCombo, combo.best)
    for record in records { counters.note(record) }

    var breakdown = XPBreakdown()
    breakdown.answers = records.map(XP.forAnswer).reduce(0, +)
    breakdown.combo = combo.bonus

    var lesson = lessons[node.id] ?? LessonProgress()
    outcome.previousStars = lesson.stars

    switch node.kind {
    case .lesson where result.gold:
      let passed = outcome.accuracy >= Curriculum.goldPassFraction && records.allSatisfy { !$0.usedHint }
      outcome.passed = passed
      breakdown.finished = XP.lessonFinished
      if passed {
        breakdown.gold = XP.goldLesson
        lesson.gold = true
        if Curriculum.lessons(inUnit: node.unit).allSatisfy({ lessons[$0.id]?.gold == true || $0.id == node.id }) {
          var unit = units[node.unit] ?? UnitProgress()
          if !unit.gold { outcome.unitGold = node.unit }
          unit.gold = true
          units[node.unit] = unit
        }
      }
      outcome.stars = lesson.stars

    case .lesson:
      let stars = LessonScoring.stars(records)
      outcome.stars = stars
      breakdown.finished = XP.lessonFinished
      if stars == 3 { breakdown.stars = XP.threeStars }
      lesson.stars = max(lesson.stars, stars)
      lesson.testedOut = false

    case .review:
      breakdown.finished = XP.lessonFinished

    case .checkpoint:
      let asked = records.filter { !$0.isReask }.count
      let right = LessonScoring.firstTryCorrect(records)
      let mark = result.testOut ? Curriculum.testOutPassMark : Curriculum.checkpointPassMark
      let needed = asked >= Curriculum.checkpointCount ? mark : Int((Double(mark) / Double(Curriculum.checkpointCount) * Double(asked)).rounded(.up))
      let passed = asked > 0 && right >= needed
      outcome.passed = passed
      if passed {
        breakdown.checkpoint = XP.checkpointPassed
        var unit = units[node.unit] ?? UnitProgress()
        unit.checkpointPassed = true
        units[node.unit] = unit
        if result.testOut { markTestedOut(upTo: node.unit) }
        outcome.unitFinished = node.unit
      }
    }

    lesson.plays += 1
    lesson.bestAccuracy = max(lesson.bestAccuracy, outcome.accuracy)
    lessons[node.id] = lesson
    if node.kind == .lesson { counters.lessonsFinished += 1 }

    // Review queue: misses come back tomorrow; reviewed items follow the spaced steps.
    for record in records {
      if node.kind == .review {
        reviewQueue.recordReview(record.exercise, correct: record.correct, today: result.day)
      } else if !record.correct {
        reviewQueue.recordMiss(record.exercise, today: result.day)
      }
    }

    let activity = noteActivity(on: result.day, hour: result.hour)
    outcome.streakEvents = activity.events
    outcome.lessonsToday = activity.lessonsToday
    outcome.goalJustMet = activity.goalJustMet

    outcome.newBadges = awardBadges(on: result.day)
    breakdown.badges = outcome.newBadges.count * XP.badge
    outcome.xp = breakdown
    outcome.levelUp = addXP(breakdown.total)
    return outcome
  }

  // MARK: Other activities

  /// A finished Daily Deal; counts as one lesson toward the daily goal. Returns nil when today's scored
  /// attempt already exists (the replay is practice).
  public mutating func recordDailyDeal(
    day: LocalDay, result: DailyDeal.Result, hour: Int = 12
  ) -> PlayOutcome? {
    guard dailyDeals[day.description] == nil else { return nil }
    dailyDeals[day.description] = DealRecord(pick: result.pick, pickDistance: result.pickDistance, pass: result.pass)
    counters.dailyDeals += 1
    return finishSideActivity(day: day, hour: hour, xp: XP.dailyDealPart * 2)
  }

  /// A finished Speed Round with `right` correct answers.
  public mutating func recordSpeedRound(
    right: Int, bestRun: Int, day: LocalDay, hour: Int = 12
  ) -> (outcome: PlayOutcome, newBest: Bool) {
    let newBest = right > speedBest
    speedBest = max(speedBest, right)
    counters.speedBest = max(counters.speedBest, right)
    counters.bestCombo = max(counters.bestCombo, bestRun)
    return (finishSideActivity(day: day, hour: hour, xp: right * XP.speedPerRight), newBest)
  }

  private mutating func finishSideActivity(day: LocalDay, hour: Int, xp amount: Int) -> PlayOutcome {
    var outcome = PlayOutcome(node: nil)
    let activity = noteActivity(on: day, hour: hour)
    outcome.streakEvents = activity.events
    outcome.lessonsToday = activity.lessonsToday
    outcome.goalJustMet = activity.goalJustMet
    outcome.newBadges = awardBadges(on: day)
    var breakdown = XPBreakdown()
    breakdown.answers = amount
    breakdown.badges = outcome.newBadges.count * XP.badge
    outcome.xp = breakdown
    outcome.levelUp = addXP(breakdown.total)
    return outcome
  }
}
