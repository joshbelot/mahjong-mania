import Foundation
import Testing

@testable import MahjongCore

private let analyzer = Analyzer.cached(for: PracticeCard.card)
private let today = LocalDay(year: 2026, month: 11, day: 2)

struct SpeedRoundTests {
  @Test func clockAddsASecondForRightAndTakesTwoForWrong() {
    var clock = SpeedClock()
    #expect(clock.remaining == 60 && !clock.isOver)
    clock.answer(correct: true)
    #expect(clock.remaining == 61 && clock.right == 1 && clock.run == 1)
    clock.answer(correct: false)
    #expect(clock.remaining == 59 && clock.wrong == 1 && clock.run == 0 && clock.bestRun == 1)
    clock.tick(10.5)
    #expect(clock.remaining == 48.5)
    clock.tick(100)
    #expect(clock.remaining == 0 && clock.isOver)
    clock.answer(correct: false)
    #expect(clock.remaining == 0)
  }

  @Test func theTimeNeverGoesNegativeAndRunsAreTracked() {
    var clock = SpeedClock()
    for _ in 0..<5 { clock.answer(correct: true) }
    clock.answer(correct: false)
    for _ in 0..<3 { clock.answer(correct: true) }
    #expect(clock.bestRun == 5 && clock.run == 3 && clock.right == 8 && clock.answered == 9)
    var low = SpeedClock()
    low.tick(59)
    low.answer(correct: false)
    #expect(low.remaining == 0 && low.isOver)
  }

  @Test func noTimerMeansThirtyQuestionsAndTheClockStandsStill() {
    var clock = SpeedClock(timed: false)
    clock.tick(1000)
    #expect(clock.remaining == 60 && !clock.isOver)
    for i in 0..<30 {
      #expect(!clock.isOver)
      clock.answer(correct: i % 3 != 0)
    }
    #expect(clock.isOver && clock.answered == 30 && clock.right == 20)
    #expect(clock.remaining == 60)
  }

  @Test func theStreamIsDeterministicAndMixesInBonusQuestions() {
    var a = SpeedStream(seed: 7, analyzer: analyzer)
    var b = SpeedStream(seed: 7, analyzer: analyzer)
    var bonus = 0
    var keeps = 0
    var targets = Set<String>()
    for i in 0..<60 {
      let qa = a.next()
      let qb = b.next()
      switch (qa, qb) {
      case (.keepPass(let la, let ra, let ta, let ka, _), .keepPass(let lb, let rb, let tb, let kb, _)):
        #expect(la.id == lb.id && ra == rb && ta == tb && ka == kb)
        #expect(ra.count == 13 && !ra.isEmpty)
        keeps += 1
        targets.insert(la.id)
        // The right answer really is "does the target use it".
        let index = analyzer.lineIndex(of: la)!
        let used = analyzer.evaluation(at: index, tiles: ra)!.usedRack[ta] ?? 0
        #expect(ka == (used > 0))
        #expect(i < SpeedStream.warmUp || (i - SpeedStream.warmUp) % 4 != 3)
      case (.bonus(let ea), .bonus(let eb)):
        bonus += 1
        #expect(ea.tiles == eb.tiles && ea.choices == eb.choices)
        #expect(i >= SpeedStream.warmUp && (i - SpeedStream.warmUp) % 4 == 3)
        #expect([ExerciseType.nameTile, .groupName].contains(ea.id.type))
      default:
        Issue.record("two streams with one seed disagreed")
      }
    }
    #expect(a.asked == 60)
    #expect(bonus == 10 && keeps == 50)
    #expect(targets.count >= 8, "targets rotate")
    var other = SpeedStream(seed: 8, analyzer: analyzer)
    var same = SpeedStream(seed: 7, analyzer: analyzer)
    var differs = false
    for _ in 0..<10 {
      if case .keepPass(let l1, _, let t1, _, _) = other.next(), case .keepPass(let l2, _, let t2, _, _) = same.next(), l1.id != l2.id || t1 != t2 { differs = true }
    }
    #expect(differs)
  }

  @Test func bothKeepAndPassAnswersOccur() {
    var stream = SpeedStream(seed: 3, analyzer: analyzer)
    var keeps = 0
    var passes = 0
    for _ in 0..<40 {
      if case .keepPass(_, _, _, let keep, _) = stream.next() { if keep { keeps += 1 } else { passes += 1 } }
    }
    #expect(keeps >= 8 && passes >= 8)
  }
}

struct FreePlayProgressTests {
  private let id = ExerciseID(type: .pickHand, seed: 4, difficulty: 3)

  @Test func rightFirstTimeEarnsXPAndCountsForBadges() {
    var p = PracticeProgress()
    var gained = 0
    for _ in 0..<20 { gained += p.recordFreePlay(AnswerRecord(exercise: id, correct: true), day: today).xp }
    #expect(p.counters.pickHandFirstTry == 20)
    #expect(p.badges[BadgeID.sharpEye.rawValue] != nil)
    #expect(gained == 20 * 5 + 20, "five XP each plus the Sharp Eye badge")
    #expect(p.xp == gained)
    #expect(p.lessonsPlayed(on: today) == 0 && p.streak.current == 0, "free play is not a lesson")
  }

  @Test func aMissGoesToTomorrowsReview() {
    var p = PracticeProgress()
    let result = p.recordFreePlay(AnswerRecord(exercise: id, correct: false), day: today)
    #expect(result.xp == 0)
    #expect(p.reviewQueue.items.first?.due == today.adding(days: 1))
  }

  @Test func aMissOnYourOwnCardIsNotQueued() {
    var p = PracticeProgress()
    _ = p.recordFreePlay(AnswerRecord(exercise: id, correct: false), day: today, queueMiss: false)
    #expect(p.reviewQueue.items.isEmpty)
  }

  @Test func freeReviewFollowsTheSpacedStepsAndCountsAsALesson() {
    var p = PracticeProgress()
    let a = ExerciseID(type: .howFar, seed: 1, difficulty: 1)
    let b = ExerciseID(type: .howFar, seed: 2, difficulty: 1)
    p.reviewQueue.recordMiss(a, today: today.adding(days: -3))
    p.reviewQueue.recordMiss(b, today: today.adding(days: -3))
    let outcome = p.applyFreeReview(
      [AnswerRecord(exercise: a, correct: true), AnswerRecord(exercise: b, correct: false)], day: today)
    #expect(outcome.xp.answers == 10 && outcome.xp.finished == 15)
    #expect(p.lessonsPlayed(on: today) == 1 && p.streak.current == 1)
    #expect(p.reviewQueue.items.first { $0.exercise == a }?.due == today.adding(days: 3))
    #expect(p.reviewQueue.items.first { $0.exercise == b }?.due == today.adding(days: 1))
  }
}
