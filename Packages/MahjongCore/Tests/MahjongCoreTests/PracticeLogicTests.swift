import Foundation
import Testing

@testable import MahjongCore

private func day(_ y: Int, _ m: Int, _ d: Int) -> LocalDay { LocalDay(year: y, month: m, day: d) }

private func recordSet(_ right: Int, of total: Int, hints: Int = 0) -> [AnswerRecord] {
  (0..<total).map { i in
    AnswerRecord(
      exercise: ExerciseID(type: .tileFact, seed: UInt64(i), difficulty: 1), correct: i < right,
      usedHint: i < hints)
  }
}

// MARK: Days

struct LocalDayTests {
  @Test func civilConversionRoundTripsAndKnownDates() {
    #expect(LocalDay(year: 1970, month: 1, day: 1).number == 0)
    #expect(LocalDay(year: 2026, month: 1, day: 1).number == 20_454)
    #expect(day(2026, 1, 1).isoWeekday == 4)  // Thursday
    #expect(day(2026, 10, 17).isoWeekday == 6)  // Saturday
    #expect(day(2026, 10, 19).isoWeekday == 1)  // Monday
    for n in stride(from: -800, to: 25_000, by: 37) {
      let d = LocalDay(number: n)
      let c = d.ymd
      #expect(LocalDay(year: c.year, month: c.month, day: c.day) == d)
    }
    #expect(day(2028, 2, 29).adding(days: 1) == day(2028, 3, 1))
    #expect(day(2026, 12, 31).adding(days: 1) == day(2027, 1, 1))
    #expect(day(2026, 10, 17).description == "2026-10-17")
    #expect(LocalDay("2026-10-17") == day(2026, 10, 17))
    #expect(LocalDay("nope") == nil)
  }

  @Test func codableAsText() throws {
    let data = try JSONEncoder().encode([day(2026, 3, 8)])
    #expect(String(decoding: data, as: UTF8.self) == "[\"2026-03-08\"]")
    #expect(try JSONDecoder().decode([LocalDay].self, from: data) == [day(2026, 3, 8)])
  }

  private func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
  }

  @Test func everyLocalDayOfTheYearComesOnceInEveryZoneEvenAcrossDST() {
    for zone in ["America/Los_Angeles", "Europe/London", "Australia/Sydney", "Pacific/Auckland", "Asia/Kolkata", "UTC", "America/Sao_Paulo"] {
      let cal = calendar(zone)
      var date = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
      var previous: LocalDay?
      for _ in 0..<366 {
        let d = LocalDay(date, calendar: cal)
        if let previous { #expect(d.number == previous.number + 1, "\(zone) \(d)") }
        previous = d
        // Add a calendar day (a 23- or 25-hour stretch on DST changes) and keep going.
        date = cal.date(byAdding: .day, value: 1, to: date)!
      }
    }
  }

  @Test func midnightBelongsToTheNewDayAndTheZoneDecides() {
    let la = calendar("America/Los_Angeles")
    let lateEvening = la.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 23, minute: 59, second: 59))!
    let midnight = la.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 0, minute: 0, second: 0))!
    #expect(LocalDay(lateEvening, calendar: la) == day(2026, 10, 17))
    #expect(LocalDay(midnight, calendar: la) == day(2026, 10, 18))
    // The same instant is already the 18th in Auckland.
    #expect(LocalDay(lateEvening, calendar: calendar("Pacific/Auckland")) == day(2026, 10, 18))
  }

  @Test func dstChangeDayStillCountsAsOneDay() {
    let la = calendar("America/Los_Angeles")
    let before = la.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 30))!
    let after = la.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 30))!
    let next = la.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30))!
    #expect(LocalDay(after, calendar: la).days(since: LocalDay(before, calendar: la)) == 1)
    #expect(LocalDay(next, calendar: la).days(since: LocalDay(after, calendar: la)) == 1)
    let fallBack = la.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 30))!
    let fallNext = la.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 5))!
    #expect(LocalDay(fallNext, calendar: la).days(since: LocalDay(fallBack, calendar: la)) == 1)
  }
}

// MARK: Streaks

struct StreakTests {
  private func play(_ state: inout StreakState, _ d: LocalDay, goal: DailyGoal = .casual) -> [StreakEvent] {
    StreakLogic.recordLesson(&state, day: d, lessonsToday: goal.lessons, goal: goal)
  }

  @Test func growsOnEachDayTheGoalIsMet() {
    var s = StreakState()
    for n in 0..<3 { _ = play(&s, day(2026, 10, 1).adding(days: n)) }
    #expect(s.current == 3 && s.longest == 3)
    // A second lesson the same day changes nothing.
    _ = play(&s, day(2026, 10, 3))
    #expect(s.current == 3)
  }

  @Test func goalOfTwoNeedsTwoLessons() {
    var s = StreakState()
    let d = day(2026, 10, 1)
    StreakLogic.recordLesson(&s, day: d, lessonsToday: 1, goal: .regular)
    #expect(s.current == 0 && s.daysPlayed == 1)
    let events = StreakLogic.recordLesson(&s, day: d, lessonsToday: 2, goal: .regular)
    #expect(s.current == 1 && events.contains(.goalMet))
    #expect(s.daysPlayed == 1)
  }

  @Test func milestonesAndFreezesEverySevenDaysUpToTwo() {
    var s = StreakState()
    var milestones: [Int] = []
    var earned = 0
    for n in 0..<22 {
      for event in play(&s, day(2026, 1, 1).adding(days: n)) {
        if case .milestone(let m) = event { milestones.append(m) }
        if case .freezeEarned = event { earned += 1 }
      }
    }
    #expect(milestones == [3, 7, 14])
    #expect(earned == 2)
    #expect(s.freezes == 2)  // the third at 21 would be a third freeze: capped at two
  }

  @Test func aFreezeKeepsTheStreakAcrossOneMissedDay() {
    var s = StreakState()
    for n in 0..<7 { _ = play(&s, day(2026, 5, 1).adding(days: n)) }
    #expect(s.freezes == 1)
    // Skip May 8, play May 9.
    let events = play(&s, day(2026, 5, 9))
    #expect(events.contains(.freezeUsed(day: day(2026, 5, 8), streak: 7)))
    #expect(s.current == 8 && s.freezes == 0)
  }

  @Test func withoutAFreezeAMissedDayResetsKindly() {
    var s = StreakState()
    for n in 0..<4 { _ = play(&s, day(2026, 5, 1).adding(days: n)) }
    let events = play(&s, day(2026, 5, 6))
    #expect(events.contains(.streakLost(previous: 4, daysPlayed: 4)))
    #expect(s.current == 1 && s.longest == 4)
    #expect(StreakLogic.brokenMessage(daysPlayed: 34) == "New streak, same skills. You've played 34 days in total.")
    #expect(!StreakLogic.brokenMessage(daysPlayed: 1).contains("1 days"))
  }

  @Test func twoFreezesCoverTwoMissedDaysButNotThree() {
    var s = StreakState()
    for n in 0..<14 { _ = play(&s, day(2026, 5, 1).adding(days: n)) }
    #expect(s.freezes == 2 && s.current == 14)
    var covered = s
    _ = play(&covered, day(2026, 5, 17))  // missed 15 and 16
    #expect(covered.current == 15 && covered.freezes == 0)
    var lost = s
    let events = play(&lost, day(2026, 5, 18))  // missed 15, 16, 17
    #expect(events.contains(.streakLost(previous: 14, daysPlayed: 14)))
    #expect(lost.current == 1)
    #expect(lost.freezes == 2, "freezes are kept when they can't save the streak")
  }

  @Test func aFreezeEarnedAndUsedInTheSameWeek() {
    var s = StreakState()
    for n in 0..<7 { _ = play(&s, day(2026, 6, 1).adding(days: n)) }  // freeze earned on day 7
    _ = play(&s, day(2026, 6, 9))  // misses June 8: freeze used, streak 8
    #expect(s.current == 8 && s.freezes == 0)
    _ = play(&s, day(2026, 6, 10))
    _ = play(&s, day(2026, 6, 11))
    #expect(s.current == 10)
  }

  @Test func longGapsResetOnce() {
    var s = StreakState()
    _ = play(&s, day(2026, 1, 1))
    let events = play(&s, day(2027, 3, 1))
    #expect(events.filter { if case .streakLost = $0 { return true } else { return false } }.count == 1)
    #expect(s.current == 1)
  }

  @Test func goingBackwardsInTimeChangesNothing() {
    var s = StreakState()
    _ = play(&s, day(2026, 7, 10))
    _ = play(&s, day(2026, 7, 11))
    let before = s
    // The phone moves west and it's "July 10" again.
    #expect(StreakLogic.settle(&s, today: day(2026, 7, 10)).isEmpty)
    _ = play(&s, day(2026, 7, 10))
    #expect(s.current == before.current && s.lastDay == before.lastDay)
  }

  @Test func displayDoesNotChangeTheState() {
    var s = StreakState()
    for n in 0..<3 { _ = play(&s, day(2026, 4, 1).adding(days: n)) }
    let shown = StreakLogic.display(s, today: day(2026, 4, 20))
    #expect(shown.current == 0 && s.current == 3)
    #expect(StreakLogic.display(s, today: day(2026, 4, 4)).current == 3)  // today still open
  }

  @Test func replayEqualsPlayingItLive() {
    let facts = (0..<40).filter { $0 % 9 != 5 }.map { (day: day(2026, 2, 1).adding(days: $0), goalMet: true) }
    var live = StreakState()
    for fact in facts { _ = play(&live, fact.day) }
    StreakLogic.settle(&live, today: day(2026, 3, 20))
    let replayed = StreakLogic.replay(facts, today: day(2026, 3, 20))
    #expect(replayed == live)
  }

  @Test func midnightLessonsLandOnTheRightDays() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    var s = StreakState()
    let late = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59, second: 59))!
    let midnight = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 0, second: 0))!
    _ = play(&s, LocalDay(late, calendar: cal))
    _ = play(&s, LocalDay(midnight, calendar: cal))  // the DST change day
    #expect(s.current == 2)
  }
}

// MARK: Levels, XP, stars

struct XPAndLevelTests {
  @Test func levelCurve() {
    #expect(Levels.xpToNext(1) == 100 && Levels.xpToNext(2) == 125 && Levels.xpToNext(10) == 325)
    #expect(Levels.position(totalXP: 0).level == 1)
    #expect(Levels.position(totalXP: 99).level == 1)
    #expect(Levels.position(totalXP: 100).level == 2)
    #expect(Levels.position(totalXP: 225).level == 3)
    let p = Levels.position(totalXP: 150)
    #expect(p.level == 2 && p.into == 50 && p.needed == 125)
    for level in 2...40 { #expect(Levels.position(totalXP: Levels.xpAtStart(of: level)).level == level) }
  }

  @Test func titles() {
    let expected = [1: "Newcomer", 2: "Newcomer", 3: "Tile Spotter", 5: "Tile Spotter", 6: "Card Reader",
      10: "Charleston Cadet", 15: "Joker Wrangler", 20: "Pattern Pro", 30: "Card Shark", 40: "Mahj Maven",
      50: "Mahjong Master", 99: "Mahjong Master"]
    for (level, title) in expected { #expect(Levels.title(level: level) == title) }
  }

  @Test func answerXP() {
    let id = ExerciseID(type: .howFar, seed: 1, difficulty: 1)
    #expect(XP.forAnswer(AnswerRecord(exercise: id, correct: true)) == 10)
    #expect(XP.forAnswer(AnswerRecord(exercise: id, correct: true, usedHint: true)) == 5)
    #expect(XP.forAnswer(AnswerRecord(exercise: id, correct: true, isReask: true)) == 5)
    #expect(XP.forAnswer(AnswerRecord(exercise: id, correct: false)) == 0)
  }

  @Test func starsFollowTheRules() {
    #expect(LessonScoring.stars(recordSet(8, of: 8)) == 3)
    #expect(LessonScoring.stars(recordSet(8, of: 8, hints: 1)) == 2, "a hint costs the third star")
    #expect(LessonScoring.stars(recordSet(6, of: 8)) == 2)
    #expect(LessonScoring.stars(recordSet(5, of: 8)) == 1)
    #expect(LessonScoring.stars(recordSet(0, of: 8)) == 1, "always finishable")
    // A re-asked miss answered right still leaves the misses on the lesson.
    var withReask = recordSet(7, of: 8)
    withReask.append(AnswerRecord(exercise: withReask[7].exercise, correct: true, isReask: true))
    #expect(LessonScoring.stars(withReask) == 2)
  }

  @Test func comboBonusIsFivePerFiveInARow() {
    #expect(LessonScoring.combo(recordSet(4, of: 8)).bonus == 0)
    #expect(LessonScoring.combo(recordSet(5, of: 8)) == (5, 5))
    let ten = recordSet(10, of: 10)
    #expect(LessonScoring.combo(ten) == (10, 10))
    var broken = recordSet(10, of: 12)
    broken[4] = AnswerRecord(exercise: broken[4].exercise, correct: false)
    #expect(LessonScoring.combo(broken).best == 5)
  }
}

// MARK: Review queue

struct ReviewQueueTests {
  private let id = ExerciseID(type: .howFar, seed: 9, difficulty: 2)

  @Test func spacedSteps() {
    var q = ReviewQueue()
    let d0 = day(2026, 10, 1)
    q.recordMiss(id, today: d0)
    #expect(q.items[0].due == day(2026, 10, 2))
    #expect(q.due(today: d0).isEmpty)
    #expect(q.due(today: day(2026, 10, 2)).count == 1)
    q.recordReview(id, correct: true, today: day(2026, 10, 2))
    #expect(q.items[0].due == day(2026, 10, 5))
    q.recordReview(id, correct: true, today: day(2026, 10, 5))
    #expect(q.items[0].due == day(2026, 10, 12))
    q.recordReview(id, correct: true, today: day(2026, 10, 12))
    #expect(q.items.isEmpty)
  }

  @Test func wrongSendsItBackToTomorrow() {
    var q = ReviewQueue()
    q.recordMiss(id, today: day(2026, 10, 1))
    q.recordReview(id, correct: true, today: day(2026, 10, 2))
    q.recordReview(id, correct: false, today: day(2026, 10, 5))
    #expect(q.items[0].step == 0 && q.items[0].due == day(2026, 10, 6))
  }

  @Test func mostOverdueFirstAndCappedAtTen() {
    var q = ReviewQueue()
    for n in 0..<15 {
      q.recordMiss(ExerciseID(type: .tileFact, seed: UInt64(n), difficulty: 1), today: day(2026, 10, 1).adding(days: n))
    }
    let due = q.due(today: day(2026, 12, 1))
    #expect(due.count == 10)
    #expect(due.map(\.due) == due.map(\.due).sorted())
    #expect(due.first?.exercise.seed == 0)
    #expect(q.dueCount(today: day(2026, 12, 1)) == 15)
  }

  @Test func missingTheSameQuestionTwiceKeepsOneItem() {
    var q = ReviewQueue()
    q.recordMiss(id, today: day(2026, 10, 1))
    q.recordMiss(id, today: day(2026, 10, 3))
    #expect(q.items.count == 1 && q.items[0].due == day(2026, 10, 4))
  }
}

// MARK: Curriculum

struct CurriculumTests {
  @Test func structureMatchesTheSpec() {
    #expect(Curriculum.units.map(\.id) == Array(1...10))
    #expect(Curriculum.units.map { $0.lessons.count } == [3, 4, 3, 4, 4, 4, 4, 4, 3, 5])
    #expect(Curriculum.units.map { $0.lessons[0].count } == [8, 8, 8, 8, 6, 6, 5, 5, 6, 8])
    for unit in Curriculum.units {
      #expect(unit.lessons.allSatisfy { $0.count == unit.lessons[0].count })
      #expect(unit.checkpoint.kind == .checkpoint && unit.nodes.last?.kind == .checkpoint)
      #expect((unit.review != nil) == (unit.id >= 3))
      if let review = unit.review {
        let index = unit.nodes.firstIndex { $0.id == review.id }!
        #expect(index == (unit.lessons.count + 1) / 2)
      }
    }
    let ids = Curriculum.allNodes.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(Curriculum.allNodes.count == 38 + 10 + 8)
  }

  @Test func exerciseMixPerUnit() {
    func types(_ unit: Int) -> Set<ExerciseType> {
      Set(Curriculum.lessons(inUnit: unit).flatMap(\.parts).flatMap(\.types))
    }
    #expect(types(1) == [.tileFact])
    #expect(types(2) == [.groupName, .matchesLine, .whichHand])
    #expect(types(3) == [.groupName, .jokerLegal, .whichHand])
    #expect(types(4) == [.howFar, .neededTile])
    #expect(types(5) == [.pickHand, .howFar])
    #expect(types(6) == [.passOne, .keepOrPass])
    #expect(types(7) == [.pickHand])
    #expect(types(8) == [.passThree])
    #expect(types(9) == [.callIt, .neededTile])
    #expect(types(10) == Set(ExerciseType.allCases))
    let ten = Curriculum.lessons(inUnit: 10).flatMap(\.parts)
    #expect(ten.allSatisfy { $0.difficulty == 3 })
  }

  @Test func lessonsHaveTheRightNumberOfQuestionsAndFocus() {
    for lesson in Curriculum.allNodes where lesson.kind == .lesson {
      let ids = Curriculum.exercises(for: lesson, seed: 7)
      #expect(ids.count == lesson.count, "\(lesson.id)")
      #expect(Set(ids.map(\.seed)).count == ids.count)
      #expect(ids == Curriculum.exercises(for: lesson, seed: 7))
      #expect(ids != Curriculum.exercises(for: lesson, seed: 8))
    }
    let winds = Curriculum.node(id: "u1l1")!
    #expect(Curriculum.exercises(for: winds, seed: 1).allSatisfy { $0.focus == ExerciseFocus.suitsAndDragons })
  }

  @Test func goldRaisesDifficultyUpToThree() {
    let lesson = Curriculum.node(id: "u4l1")!
    let normal = Curriculum.exercises(for: lesson, seed: 3)
    let gold = Curriculum.exercises(for: lesson, seed: 3, gold: true)
    #expect(zip(normal, gold).allSatisfy { $1.difficulty == min(3, $0.difficulty + 1) })
    let ten = Curriculum.exercises(for: Curriculum.node(id: "u10l1")!, seed: 3, gold: true)
    #expect(ten.allSatisfy { $0.difficulty == 3 })
  }

  @Test func checkpointsAreTenWithThreeFromEarlierUnits() {
    for unit in Curriculum.units {
      let ids = Curriculum.exercises(for: unit.checkpoint, seed: 5)
      #expect(ids.count == 10)
      let hardest = Curriculum.hardestParts(of: unit)
      let own = ids.filter { id in hardest.contains { $0.types == [id.type] && $0.difficulty == id.difficulty } }
      if unit.id == 1 {
        #expect(own.count == 10)
      } else {
        // At least seven are the unit's own types at its hardest level; the rest come from earlier units.
        #expect(own.count >= 7, "unit \(unit.id)")
        let earlierTypes = Set(
          Curriculum.units.filter { $0.id < unit.id }.flatMap { Curriculum.lessons(inUnit: $0.id) }
            .flatMap(\.parts).flatMap(\.types))
        let others = ids.filter { id in !own.contains(id) }
        #expect(others.count <= 3)
        #expect(others.allSatisfy { earlierTypes.contains($0.type) })
      }
      #expect(ids.allSatisfy { $0.focus == 0 })
    }
  }

  @Test func reviewNodesUseDueItemsThenFillFromTheUnit() {
    let review = Curriculum.node(id: "u3r")!
    let due = (0..<3).map { ExerciseID(type: .howFar, seed: UInt64($0), difficulty: 2) }
    let ids = Curriculum.exercises(for: review, seed: 1, review: due)
    #expect(ids.count == 8 && Array(ids.prefix(3)) == due)
    #expect(Curriculum.exercises(for: review, seed: 1).count == 8)
    let many = (0..<20).map { ExerciseID(type: .tileFact, seed: UInt64($0), difficulty: 1) }
    #expect(Curriculum.exercises(for: review, seed: 1, review: many) == Array(many.prefix(8)))
  }

  @Test func everyNodeBuildsGradableQuestions() {
    let analyzer = Analyzer.cached(for: PracticeCard.card)
    for node in Curriculum.allNodes {
      for gold in [false, true] where !(gold && node.kind != .lesson) {
        for id in Curriculum.exercises(for: node, seed: 11, gold: gold) {
          let exercise = Exercises.make(id, analyzer: analyzer)
          #expect(!exercise.prompt.isEmpty, "\(node.id) \(id)")
        }
      }
    }
  }

  @Test func skillsCoverEveryType() {
    for type in ExerciseType.allCases { _ = Curriculum.skill(of: type) }
    #expect(Set(ExerciseType.allCases.map(Curriculum.skill(of:))).count == Curriculum.Skill.allCases.count)
  }
}
