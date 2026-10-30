import Foundation

public enum BadgeID: String, Codable, CaseIterable, Sendable {
  case firstSteps, tileWhisperer, cardReader, jokersWild, charlestonChamp, sharpEye, perfectionist,
    goldRush, onFire, weekWarrior, monthlyRegular, earlyBird, nightOwl, dailyDealer, speedDemon,
    comeback, graduate, perfectWeek

  public var title: String {
    switch self {
    case .firstSteps: return "First Steps"
    case .tileWhisperer: return "Tile Whisperer"
    case .cardReader: return "Card Reader"
    case .jokersWild: return "Joker's Wild"
    case .charlestonChamp: return "Charleston Champ"
    case .sharpEye: return "Sharp Eye"
    case .perfectionist: return "Perfectionist"
    case .goldRush: return "Gold Rush"
    case .onFire: return "On Fire"
    case .weekWarrior: return "Week Warrior"
    case .monthlyRegular: return "Monthly Regular"
    case .earlyBird: return "Early Bird"
    case .nightOwl: return "Night Owl"
    case .dailyDealer: return "Daily Dealer"
    case .speedDemon: return "Speed Demon"
    case .comeback: return "Comeback"
    case .graduate: return "Graduate"
    case .perfectWeek: return "Perfect Week"
    }
  }

  /// What earns it (shown on locked badges).
  public var goal: String {
    switch self {
    case .firstSteps: return "Finish any lesson"
    case .tileWhisperer: return "Finish Unit 1"
    case .cardReader: return "Finish Unit 2"
    case .jokersWild: return "Finish Unit 3"
    case .charlestonChamp: return "Pass three tiles well, first try, 10 times"
    case .sharpEye: return "Pick the right hand first try, 20 times"
    case .perfectionist: return "Earn three stars on 10 lessons"
    case .goldRush: return "Make any unit gold"
    case .onFire: return "Answer 15 in a row"
    case .weekWarrior: return "Reach a 7-day streak"
    case .monthlyRegular: return "Reach a 30-day streak"
    case .earlyBird: return "Finish a lesson before 8:00"
    case .nightOwl: return "Finish a lesson after 22:00"
    case .dailyDealer: return "Play 7 Daily Deals"
    case .speedDemon: return "Answer 25 in one Speed Round"
    case .comeback: return "Get a repeated mistake right 25 times"
    case .graduate: return "Finish Unit 10"
    case .perfectWeek: return "Meet your daily goal 7 days in a row, with every lesson at three stars"
    }
  }

  public var symbol: String {
    switch self {
    case .firstSteps: return "figure.walk"
    case .tileWhisperer: return "square.grid.3x3.fill"
    case .cardReader: return "book.fill"
    case .jokersWild: return "theatermasks.fill"
    case .charlestonChamp: return "arrow.left.arrow.right"
    case .sharpEye: return "eye.fill"
    case .perfectionist: return "star.fill"
    case .goldRush: return "crown.fill"
    case .onFire: return "flame.fill"
    case .weekWarrior: return "calendar"
    case .monthlyRegular: return "calendar.badge.clock"
    case .earlyBird: return "sunrise.fill"
    case .nightOwl: return "moon.stars.fill"
    case .dailyDealer: return "rectangle.stack.fill"
    case .speedDemon: return "bolt.fill"
    case .comeback: return "arrow.counterclockwise"
    case .graduate: return "graduationcap.fill"
    case .perfectWeek: return "sparkles"
    }
  }

  /// The one rare badge, shown with a gold frame.
  public var isRare: Bool { self == .perfectWeek }

  /// XP paid when it is earned.
  public var xp: Int { self == .perfectWeek ? XP.perfectWeek : XP.badge }
}

/// Running totals that badges and the profile read.
public struct PracticeCounters: Hashable, Codable, Sendable {
  public var lessonsFinished = 0
  public var threeStarLessons = 0
  public var passThreeFirstTry = 0
  public var pickHandFirstTry = 0
  public var bestCombo = 0
  public var reaskRight = 0
  public var earlyLessons = 0
  public var nightLessons = 0
  public var dailyDeals = 0
  public var speedBest = 0
  /// Per skill: right first time and asked, for the profile's accuracy bars.
  public var skillRight: [String: Int] = [:]
  public var skillAsked: [String: Int] = [:]

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case lessonsFinished, threeStarLessons, passThreeFirstTry, pickHandFirstTry, bestCombo, reaskRight,
      earlyLessons, nightLessons, dailyDeals, speedBest, skillRight, skillAsked
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    func int(_ key: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: key) ?? 0 }
    lessonsFinished = try int(.lessonsFinished)
    threeStarLessons = try int(.threeStarLessons)
    passThreeFirstTry = try int(.passThreeFirstTry)
    pickHandFirstTry = try int(.pickHandFirstTry)
    bestCombo = try int(.bestCombo)
    reaskRight = try int(.reaskRight)
    earlyLessons = try int(.earlyLessons)
    nightLessons = try int(.nightLessons)
    dailyDeals = try int(.dailyDeals)
    speedBest = try int(.speedBest)
    skillRight = try c.decodeIfPresent([String: Int].self, forKey: .skillRight) ?? [:]
    skillAsked = try c.decodeIfPresent([String: Int].self, forKey: .skillAsked) ?? [:]
  }

  public mutating func note(_ record: AnswerRecord) {
    let skill = Curriculum.skill(of: record.exercise.type).rawValue
    if !record.isReask {
      skillAsked[skill, default: 0] += 1
      if record.correct && !record.usedHint { skillRight[skill, default: 0] += 1 }
    }
    guard record.correct else { return }
    if record.isReask { reaskRight += 1 }
    if record.cleanFirstTry {
      if record.exercise.type == .passThree { passThreeFirstTry += 1 }
      if record.exercise.type == .pickHand { pickHandFirstTry += 1 }
    }
  }

  /// Right-first-time share for `skill`, nil until something was asked.
  public func accuracy(_ skill: Curriculum.Skill) -> Double? {
    guard let asked = skillAsked[skill.rawValue], asked > 0 else { return nil }
    return Double(skillRight[skill.rawValue] ?? 0) / Double(asked)
  }
}

public enum Badges {
  /// Every badge the player has earned by now.
  public static func earned(
    counters: PracticeCounters, finishedUnits: Set<Int>, goldUnits: Set<Int>, streak: StreakState,
    perfectWeek: Bool = false
  ) -> Set<BadgeID> {
    var result = Set<BadgeID>()
    if counters.lessonsFinished >= 1 { result.insert(.firstSteps) }
    if finishedUnits.contains(1) { result.insert(.tileWhisperer) }
    if finishedUnits.contains(2) { result.insert(.cardReader) }
    if finishedUnits.contains(3) { result.insert(.jokersWild) }
    if counters.passThreeFirstTry >= 10 { result.insert(.charlestonChamp) }
    if counters.pickHandFirstTry >= 20 { result.insert(.sharpEye) }
    if counters.threeStarLessons >= 10 { result.insert(.perfectionist) }
    if !goldUnits.isEmpty { result.insert(.goldRush) }
    if counters.bestCombo >= 15 { result.insert(.onFire) }
    if streak.longest >= 7 { result.insert(.weekWarrior) }
    if streak.longest >= 30 { result.insert(.monthlyRegular) }
    if counters.earlyLessons >= 1 { result.insert(.earlyBird) }
    if counters.nightLessons >= 1 { result.insert(.nightOwl) }
    if counters.dailyDeals >= 7 { result.insert(.dailyDealer) }
    if counters.speedBest >= 25 { result.insert(.speedDemon) }
    if counters.reaskRight >= 25 { result.insert(.comeback) }
    if finishedUnits.contains(10) { result.insert(.graduate) }
    if perfectWeek { result.insert(.perfectWeek) }
    return result
  }
}
