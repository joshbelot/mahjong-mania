import Foundation
import Testing

@testable import MahjongCore

private func day(_ y: Int, _ m: Int, _ d: Int) -> LocalDay { LocalDay(year: y, month: m, day: d) }
private let today = day(2026, 10, 19)

private func records(_ node: String, right: Int, hints: Int = 0, total: Int? = nil) -> [AnswerRecord] {
  let spec = Curriculum.node(id: node)!
  let ids = Curriculum.exercises(for: spec, seed: 1)
  let count = total ?? ids.count
  return (0..<count).map { i in
    AnswerRecord(exercise: ids[i % ids.count], correct: i < right, usedHint: i < hints)
  }
}

@discardableResult
private func play(
  _ p: inout PracticeProgress, _ node: String, right: Int, total: Int? = nil, gold: Bool = false,
  testOut: Bool = false, on d: LocalDay = today, hour: Int = 12
) -> PlayOutcome {
  p.apply(
    PlayResult(
      nodeID: node, gold: gold, testOut: testOut, records: records(node, right: right, total: total), day: d,
      hour: hour))!
}

struct PathTests {
  @Test func aNewPlayerStartsAtLessonOne() {
    let p = PracticeProgress()
    #expect(p.nextNode?.spec.id == "u1l1")
    let nodes = p.nodes()
    #expect(nodes.filter { $0.status == .next }.count == 1)
    #expect(nodes.dropFirst().allSatisfy { $0.status == .locked })
  }

  @Test func finishingALessonUnlocksTheNextNodeEvenWithManyMistakes() {
    var p = PracticeProgress()
    let outcome = play(&p, "u1l1", right: 0)
    #expect(outcome.stars == 1)
    #expect(p.nextNode?.spec.id == "u1l2")
    play(&p, "u1l2", right: 8)
    play(&p, "u1l3", right: 6)
    play(&p, "u1l4", right: 8)
    #expect(p.nextNode?.spec.id == "u1c")
    #expect(p.nodes().first { $0.id == "u1l2" }?.stars == 3)
  }

  @Test func bestStarsAreKept() {
    var p = PracticeProgress()
    play(&p, "u1l1", right: 8)
    let again = play(&p, "u1l1", right: 4)
    #expect(again.previousStars == 3 && !again.improvedStars)
    #expect(p.lessons["u1l1"]?.stars == 3 && p.lessons["u1l1"]?.plays == 2)
  }

  @Test func checkpointNeedsSevenOfTenAndUnlocksTheNextUnit() {
    var p = PracticeProgress()
    for l in 1...4 { play(&p, "u1l\(l)", right: 8) }
    let failed = play(&p, "u1c", right: 6)
    #expect(!failed.passed && p.nextNode?.spec.id == "u1c" && !p.isUnitFinished(1))
    let passed = play(&p, "u1c", right: 7)
    #expect(passed.passed && passed.unitFinished == 1)
    #expect(p.isUnitFinished(1) && p.nextNode?.spec.id == "u2l1")
    #expect(passed.xp.checkpoint == 30)
  }

  @Test func testingOutNeedsEightAndUnlocksEverythingBefore() {
    var p = PracticeProgress()
    #expect(p.canTestOut(3))
    let failed = play(&p, "u3c", right: 7, testOut: true)
    #expect(!failed.passed && p.nextNode?.spec.id == "u1l1")
    let passed = play(&p, "u3c", right: 8, testOut: true)
    #expect(passed.passed)
    #expect(p.nextNode?.spec.id == "u4l1")
    let nodes = p.nodes()
    #expect(nodes.filter { $0.spec.unit <= 2 }.allSatisfy { $0.status == .testedOut })
    #expect(nodes.first { $0.id == "u3c" }?.status == .done)
    #expect(p.isUnitFinished(1) && p.isUnitFinished(2) && p.isUnitFinished(3))
    #expect(!p.canTestOut(2))
    #expect(p.finishedUnits == [1, 2, 3])
  }

  @Test func testingOutKeepsEarnedStars() {
    var p = PracticeProgress()
    play(&p, "u1l1", right: 8)
    play(&p, "u2c", right: 9, testOut: true)
    #expect(p.nodes().first { $0.id == "u1l1" }?.status == .done)
    #expect(p.nodes().first { $0.id == "u1l1" }?.stars == 3)
    #expect(p.nodes().first { $0.id == "u1l2" }?.status == .testedOut)
  }

  @Test func placementChoices() {
    var basics = PracticeProgress()
    basics.applyPlacement(.basics)
    #expect(basics.nextNode?.spec.id == "u4l1")
    var regular = PracticeProgress()
    regular.applyPlacement(.regular)
    #expect(regular.nextNode?.spec.id == "u7l1")
    var new = PracticeProgress()
    new.applyPlacement(.new)
    #expect(new.nextNode?.spec.id == "u1l1" && new.placement == .new)
  }

  @Test func reviewNodesAreDoneOncePlayed() {
    var p = PracticeProgress()
    p.applyPlacement(.basics)
    play(&p, "u4l1", right: 8)
    play(&p, "u4l2", right: 8)
    #expect(p.nextNode?.spec.id == "u4r")
    play(&p, "u4r", right: 3)
    #expect(p.nextNode?.spec.id == "u4l3")
  }

  @Test func goldNeedsThreeStarsEverywhereThenNinetyPercent() {
    var p = PracticeProgress()
    for l in 1...4 { play(&p, "u1l\(l)", right: l == 4 ? 7 : 8) }
    #expect(!p.goldAvailable(1))
    play(&p, "u1l4", right: 8)
    #expect(p.goldAvailable(1))
    let weak = play(&p, "u1l1", right: 7, gold: true)  // 87.5%
    #expect(!weak.passed && p.lessons["u1l1"]?.gold != true)
    var unitGold: Int?
    for l in 1...4 {
      let o = play(&p, "u1l\(l)", right: 8, gold: true)
      #expect(o.passed && o.xp.gold == 20)
      unitGold = o.unitGold ?? unitGold
    }
    #expect(unitGold == 1 && p.units[1]?.gold == true && !p.goldAvailable(1))
    #expect(p.nodes().first { $0.id == "u1l2" }?.gold == true)
  }

  @Test func goldWithAHintDoesNotCount() {
    var p = PracticeProgress()
    let o = p.apply(PlayResult(nodeID: "u1l1", gold: true, records: records("u1l1", right: 8, hints: 1), day: today))!
    #expect(!o.passed)
  }
}

struct ApplyTests {
  @Test func xpBreakdownForAPerfectLesson() {
    var p = PracticeProgress()
    let o = play(&p, "u1l1", right: 8)
    #expect(o.xp.answers == 80 && o.xp.combo == 5 && o.xp.finished == 15 && o.xp.stars == 10)
    #expect(o.xp.badges == 20, "First Steps")
    #expect(o.xp.total == 130 && p.xp == 130)
    #expect(o.stars == 3 && o.accuracy == 1 && o.bestCombo == 8)
  }

  @Test func hintsAndReasksPayLess() {
    var p = PracticeProgress()
    var rs = records("u1l1", right: 8, hints: 2)
    rs[7] = AnswerRecord(exercise: rs[7].exercise, correct: false)
    rs.append(AnswerRecord(exercise: rs[7].exercise, correct: true, isReask: true))
    let o = p.apply(PlayResult(nodeID: "u1l1", records: rs, day: today))!
    #expect(o.xp.answers == 2 * 5 + 5 * 10 + 0 + 5)
    #expect(o.stars == 2)
  }

  @Test func levelUpIsReportedOnceAndBadgesPayOnce() {
    var p = PracticeProgress()
    let first = play(&p, "u1l1", right: 8)  // 130 XP: level 2
    #expect(first.levelUp?.level == 2 && first.levelUp?.title == "Newcomer")
    let second = play(&p, "u1l1", right: 8)  // +115: level 3
    #expect(second.levelUp?.level == 3)
    #expect(second.newBadges.isEmpty && second.xp.badges == 0)
    let third = play(&p, "u1l1", right: 8)  // 360 XP: still level 3
    #expect(third.levelUp == nil)
    #expect(p.badges[BadgeID.firstSteps.rawValue] == today)
  }

  @Test func bigJumpsCelebrateTheNewLevelOnly() {
    var p = PracticeProgress()
    p.xp = 150
    let o = play(&p, "u1l1", right: 8)
    #expect(o.levelUp?.level == 3)
    #expect(p.levelsCelebrated == 3)
  }

  @Test func missesJoinTheReviewQueueForTomorrow() {
    var p = PracticeProgress()
    let o = play(&p, "u1l1", right: 6)
    #expect(o.stars == 2)
    #expect(p.reviewQueue.items.count == 2)
    #expect(p.reviewQueue.items.allSatisfy { $0.due == today.adding(days: 1) })
    #expect(p.reviewQueue.due(today: today).isEmpty)
  }

  @Test func reviewNodeUpdatesTheQueueBySpacedSteps() {
    var p = PracticeProgress()
    p.applyPlacement(.basics)
    let miss = ExerciseID(type: .howFar, seed: 5, difficulty: 1)
    p.reviewQueue.recordMiss(miss, today: today.adding(days: -2))
    let rs = [AnswerRecord(exercise: miss, correct: true)]
    _ = p.apply(PlayResult(nodeID: "u4r", records: rs, day: today))
    #expect(p.reviewQueue.items.first?.due == today.adding(days: 3))
  }

  @Test func playsCountTowardTheDailyGoalAndStreak() {
    var p = PracticeProgress()
    p.dailyGoal = .regular
    let a = play(&p, "u1l1", right: 8)
    #expect(!a.goalJustMet && a.lessonsToday == 1 && p.streak.current == 0)
    let b = play(&p, "u1l2", right: 8)
    #expect(b.goalJustMet && b.lessonsToday == 2 && p.streak.current == 1)
    let c = play(&p, "u1l3", right: 8)
    #expect(!c.goalJustMet && p.streak.current == 1)
    #expect(p.goalMet(on: today) && p.lessonsPlayed(on: today) == 3)
    let next = play(&p, "u1l4", right: 8, on: today.adding(days: 1))
    #expect(next.lessonsToday == 1 && p.streak.current == 1)
  }

  @Test func checkpointsReviewsAndGoldAllCountAsOneLesson() {
    var p = PracticeProgress()
    p.applyPlacement(.basics)
    play(&p, "u4c", right: 3, testOut: false)  // a failed checkpoint still counts as a play
    #expect(p.lessonsPlayed(on: today) == 1)
  }

  @Test func earlyBirdAndNightOwl() {
    var p = PracticeProgress()
    play(&p, "u1l1", right: 8, hour: 7)
    play(&p, "u1l2", right: 8, hour: 22)
    #expect(p.badges[BadgeID.earlyBird.rawValue] != nil && p.badges[BadgeID.nightOwl.rawValue] != nil)
  }

  @Test func unitBadgesAndGraduate() {
    var p = PracticeProgress()
    for l in 1...4 { play(&p, "u1l\(l)", right: 8) }
    #expect(p.badges[BadgeID.tileWhisperer.rawValue] == nil)
    play(&p, "u1c", right: 9)
    #expect(p.badges[BadgeID.tileWhisperer.rawValue] != nil)
    var q = PracticeProgress()
    play(&q, "u10c", right: 10, testOut: true)
    #expect(q.badges[BadgeID.graduate.rawValue] != nil)
    #expect(q.badges[BadgeID.jokersWild.rawValue] != nil)
  }

  @Test func speedRoundAndDailyDealCountAsALessonEach() {
    var p = PracticeProgress()
    let (outcome, newBest) = p.recordSpeedRound(right: 26, bestRun: 17, day: today)
    #expect(newBest && p.speedBest == 26 && outcome.xp.answers == 52)
    #expect(p.badges[BadgeID.speedDemon.rawValue] != nil && p.badges[BadgeID.onFire.rawValue] != nil)
    #expect(!p.recordSpeedRound(right: 10, bestRun: 3, day: today).newBest)
    let result = DailyDeal.Result(pick: .best, pickDistance: 3, pass: [.green, .green, .yellow])
    #expect(p.recordDailyDeal(day: today, result: result)?.xp.answers == 50)
    #expect(p.recordDailyDeal(day: today, result: result) == nil, "one scored attempt per day")
    #expect(p.lessonsPlayed(on: today) == 3)
  }

  @Test func jsonRoundTripAndOldFiles() throws {
    var p = PracticeProgress()
    p.applyPlacement(.basics)
    play(&p, "u4l1", right: 7)
    _ = p.recordDailyDeal(day: today, result: .init(pick: .good, pickDistance: 4, pass: [.red]))
    let data = try JSONEncoder().encode(p)
    #expect(try JSONDecoder().decode(PracticeProgress.self, from: data) == p)
    let empty = try JSONDecoder().decode(PracticeProgress.self, from: Data("{}".utf8))
    #expect(empty == PracticeProgress())
  }

  @Test func theDayLogKeepsFourHundredDays() {
    var p = PracticeProgress()
    for n in 0..<430 { play(&p, "u1l1", right: 8, on: today.adding(days: n)) }
    #expect(p.dayLog.count <= 401)
    #expect(p.streak.current == 430)
  }

  @Test func openingTheAppAfterABreakSettlesTheStreak() {
    var p = PracticeProgress()
    for n in 0..<3 { play(&p, "u1l1", right: 8, on: today.adding(days: n)) }
    let events = p.openDay(today.adding(days: 10))
    #expect(events == [.streakLost(previous: 3, daysPlayed: 3)])
    #expect(p.streak.current == 0 && p.streak.longest == 3)
  }
}

struct BadgeTests {
  @Test func thresholds() {
    var c = PracticeCounters()
    var s = StreakState()
    #expect(Badges.earned(counters: c, finishedUnits: [], goldUnits: [], streak: s).isEmpty)
    c.passThreeFirstTry = 10
    c.pickHandFirstTry = 20
    c.threeStarLessons = 10
    c.bestCombo = 15
    c.dailyDeals = 7
    c.speedBest = 25
    c.reaskRight = 25
    s.longest = 30
    let all = Badges.earned(counters: c, finishedUnits: [], goldUnits: [2], streak: s)
    for badge in [BadgeID.charlestonChamp, .sharpEye, .perfectionist, .onFire, .dailyDealer, .speedDemon, .comeback, .goldRush, .weekWarrior, .monthlyRegular] {
      #expect(all.contains(badge), "\(badge)")
    }
    c.passThreeFirstTry = 9
    #expect(!Badges.earned(counters: c, finishedUnits: [], goldUnits: [], streak: StreakState()).contains(.charlestonChamp))
  }

  @Test func everyBadgeHasWordsAndAnIcon() {
    #expect(BadgeID.allCases.count == 17)
    for badge in BadgeID.allCases {
      #expect(!badge.title.isEmpty && !badge.goal.isEmpty && !badge.symbol.isEmpty)
    }
  }

  @Test func countersTrackSkillsAndFirstTries() {
    var c = PracticeCounters()
    let pass = ExerciseID(type: .passThree, seed: 1, difficulty: 2)
    c.note(AnswerRecord(exercise: pass, correct: true))
    c.note(AnswerRecord(exercise: pass, correct: true, usedHint: true))
    c.note(AnswerRecord(exercise: pass, correct: false))
    c.note(AnswerRecord(exercise: pass, correct: true, isReask: true))
    #expect(c.passThreeFirstTry == 1 && c.reaskRight == 1)
    #expect(c.accuracy(.charleston) == 1.0 / 3.0)
    #expect(c.accuracy(.tiles) == nil)
  }
}

struct DailyDealTests {
  private let analyzer = Analyzer.cached(for: PracticeCard.card)

  @Test func numberSeedAndWeekday() {
    #expect(DailyDeal.number(for: day(2026, 1, 1)) == 0)
    #expect(DailyDeal.number(for: day(2026, 10, 17)) == 289)
    var expected = SeededRandom(seed: UInt64(289) ^ 0x4D4A)
    #expect(DailyDeal.seed(for: day(2026, 10, 17)) == expected.next())
    #expect(DailyDeal.seed(for: day(2026, 10, 17)) != DailyDeal.seed(for: day(2026, 10, 18)))
    #expect(DailyDeal.difficulty(for: day(2026, 10, 19)) == 1)  // Monday
    #expect(DailyDeal.difficulty(for: day(2026, 10, 25)) == 7)  // Sunday
  }

  @Test func everyoneGetsTheSameDealOnTheSameDay() {
    let a = DailyDeal.deal(for: day(2026, 11, 2), analyzer: analyzer)
    let b = DailyDeal.deal(for: day(2026, 11, 2), analyzer: Analyzer(card: PracticeCard.card))
    #expect(a.hand == b.hand && a.hand.count == 13)
    #expect(a.hand != DailyDeal.deal(for: day(2026, 11, 3), analyzer: analyzer).hand)
  }

  @Test func weekdayFiltersShapeTheDeals() {
    var passed = [Int: Int]()
    for offset in 0..<28 {
      let d = day(2026, 11, 2).adding(days: offset)  // starts on a Monday
      let deal = DailyDeal.deal(for: d, analyzer: analyzer)
      let results = analyzer.analyze(PlayerView(rack: deal.hand))
      let gap = DailyDeal.gap(results)
      let level = DailyDeal.difficulty(for: d)
      let ok: Bool
      switch level {
      case 1, 2, 4: ok = gap >= 2
      case 3: ok = gap >= 1
      case 5: ok = true
      case 6: ok = gap <= 1
      default: ok = gap <= 1 && (results.first { $0.best.possible }?.best.distance ?? 0) >= 8
      }
      if ok { passed[level, default: 0] += 1 }
    }
    #expect(passed.values.reduce(0, +) >= 27, "\(passed)")
    // Mondays are clearer than Sundays.
    let monday = DailyDeal.deal(for: day(2026, 11, 2), analyzer: analyzer)
    let sunday = DailyDeal.deal(for: day(2026, 11, 8), analyzer: analyzer)
    let mondayBest = analyzer.analyze(PlayerView(rack: monday.hand)).first!.best.distance
    let sundayBest = analyzer.analyze(PlayerView(rack: sunday.hand)).first!.best.distance
    #expect(mondayBest < sundayBest)
  }

  @Test func theTwoQuestionsShareTheDealAndGrade() {
    let (pick, pass) = DailyDeal.exercises(for: day(2026, 11, 4), analyzer: analyzer)
    #expect(pick.tiles == pass.tiles && pick.choices.count == 37 && pass.selectCount == 3)
    let best = analyzer.analyze(PlayerView(rack: pick.tiles)).first!
    let index = pick.choices.firstIndex { if case .line(let l) = $0 { return l.id == best.line.id } else { return false } }!
    #expect(Exercises.grade(pick, answer: .choice(index), analyzer: analyzer).correct)
    let advice = analyzer.suggestPasses(PlayerView(rack: pass.tiles), count: 3).passes.map(\.tile)
    var left = advice
    var picks: [Int] = []
    for (i, t) in pass.tiles.enumerated() { if let at = left.firstIndex(of: t) { left.remove(at: at); picks.append(i) } }
    #expect(Exercises.grade(pass, answer: .tiles(picks), analyzer: analyzer).correct)
  }

  @Test func resultMarksAndShareText() {
    let deal = DailyDeal.deal(for: day(2026, 11, 4), analyzer: analyzer)
    let results = analyzer.analyze(PlayerView(rack: deal.hand))
    let best = results.first!
    let advice = analyzer.suggestPasses(PlayerView(rack: deal.hand), count: 3).passes.map(\.tile)
    var left = advice
    var picks: [Int] = []
    for (i, t) in deal.hand.enumerated() { if let at = left.firstIndex(of: t) { left.remove(at: at); picks.append(i) } }
    let good = DailyDeal.result(hand: deal.hand, pickedLine: best.line, passSelection: picks, analyzer: analyzer)
    #expect(good.pick == .best && good.pass == [.green, .green, .green])
    // Passing a tile the best hand uses is a red square.
    let used = deal.hand.indices.first { (best.best.usedRack[deal.hand[$0]] ?? 0) > 0 }!
    let rest = deal.hand.indices.filter { $0 != used }.prefix(2)
    let bad = DailyDeal.result(hand: deal.hand, pickedLine: best.line, passSelection: [used] + rest, analyzer: analyzer)
    #expect(bad.pass.first == .red)
    let far = results.last { $0.best.possible }!
    #expect(DailyDeal.result(hand: deal.hand, pickedLine: far.line, passSelection: picks, analyzer: analyzer).pick == .miss)

    let text = DailyDeal.shareText(
      number: 289, result: .init(pick: .best, pickDistance: 3, pass: [.green, .green, .yellow]), streak: 12)
    #expect(text == "Mahjong Mania Daily #289 🀄\nPick: ✅ (best hand, 3 away)\nPass: 🟩🟩🟨\n🔥 12-day streak")
    let noStreak = DailyDeal.shareText(number: 5, result: .init(pick: .miss, pickDistance: 7, pass: [.red]), streak: 0)
    #expect(noStreak == "Mahjong Mania Daily #5 🀄\nPick: ❌ (7 away)\nPass: 🟥")
  }
}
