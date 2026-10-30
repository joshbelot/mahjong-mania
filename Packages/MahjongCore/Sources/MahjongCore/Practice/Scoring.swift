import Foundation

/// One answer given during a play.
public struct AnswerRecord: Hashable, Codable, Sendable {
  public var exercise: ExerciseID
  public var correct: Bool
  public var usedHint: Bool
  /// True for a mistake re-asked at the end of the lesson.
  public var isReask: Bool

  public init(exercise: ExerciseID, correct: Bool, usedHint: Bool = false, isReask: Bool = false) {
    self.exercise = exercise
    self.correct = correct
    self.usedHint = usedHint
    self.isReask = isReask
  }

  /// Right first time, without help.
  public var cleanFirstTry: Bool { correct && !usedHint && !isReask }
}

/// XP amounts (SPEC §18.6).
public enum XP {
  public static let firstTry = 10
  public static let afterHint = 5
  public static let reAsked = 5
  public static let lessonFinished = 15
  public static let threeStars = 10
  public static let checkpointPassed = 30
  public static let goldLesson = 20
  public static let dailyDealPart = 25
  public static let speedPerRight = 2
  public static let comboBonus = 5
  public static let comboEvery = 5
  public static let badge = 20
  /// The rare Perfect Week badge.
  public static let perfectWeek = 50
  public static func badges(_ list: [BadgeID]) -> Int { list.map(\.xp).reduce(0, +) }
  /// A free-play question right first time.
  public static let freePlayRight = 5

  public static func forAnswer(_ record: AnswerRecord) -> Int {
    guard record.correct else { return 0 }
    if record.isReask { return reAsked }
    return record.usedHint ? afterHint : firstTry
  }
}

public enum LessonScoring {
  /// Longest run of right answers (a re-asked right answer keeps the run going) and the bonus XP for it:
  /// +5 each time the run reaches a multiple of 5.
  public static func combo(_ records: [AnswerRecord]) -> (best: Int, bonus: Int) {
    var run = 0
    var best = 0
    var bonus = 0
    for record in records {
      if record.correct {
        run += 1
        best = max(best, run)
        if run % XP.comboEvery == 0 { bonus += XP.comboBonus }
      } else {
        run = 0
      }
    }
    return (best, bonus)
  }

  /// Wrong first answers (re-asked questions don't count against the lesson).
  public static func misses(_ records: [AnswerRecord]) -> Int {
    records.filter { !$0.isReask && !$0.correct }.count
  }

  /// ★★★ every question right first time with no hint; ★★ at most two misses; ★ finished.
  public static func stars(_ records: [AnswerRecord]) -> Int {
    let firsts = records.filter { !$0.isReask }
    if !firsts.isEmpty && firsts.allSatisfy(\.cleanFirstTry) { return 3 }
    return misses(records) <= 2 ? 2 : 1
  }

  /// Share of the questions answered right first time (hints allowed), 0...1.
  public static func firstTryAccuracy(_ records: [AnswerRecord]) -> Double {
    let firsts = records.filter { !$0.isReask }
    guard !firsts.isEmpty else { return 0 }
    return Double(firsts.filter(\.correct).count) / Double(firsts.count)
  }

  public static func firstTryCorrect(_ records: [AnswerRecord]) -> Int {
    records.filter { !$0.isReask && $0.correct }.count
  }

  /// Right on the first try with no hint.
  public static func cleanCorrect(_ records: [AnswerRecord]) -> Int {
    records.filter(\.cleanFirstTry).count
  }
}
