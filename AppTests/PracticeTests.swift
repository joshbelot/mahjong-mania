import AVFoundation
import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)
private let analyzer = Analyzer.cached(for: PracticeCard.card)
private let today = LocalDay(year: 2026, month: 11, day: 2)

/// Answers the session's current question correctly without going through the screen.
@MainActor
private func answerRight(_ session: LessonSession) {
  guard let exercise = session.exercise else { return }
  if exercise.id.type == .keepOrPass {
    for index in exercise.queue.indices { session.decide(keep: exercise.shouldKeep(queueIndex: index) ?? true) }
  } else if exercise.selectCount > 0 {
    for position in exercise.tiles.indices where exercise.canSelect(position: position) {
      var candidate = session.selectedTiles
      candidate = [position]
      if exercise.selectCount == 1,
        Exercises.grade(exercise, answer: .tiles(candidate), analyzer: analyzer).correct
      {
        session.toggleTile(position)
        break
      }
    }
    if exercise.selectCount == 3 {
      var advice = analyzer.suggestPasses(PlayerView(rack: exercise.tiles), count: 3).passes.map(\.tile)
      for (position, tile) in exercise.tiles.enumerated() {
        if let at = advice.firstIndex(of: tile) {
          advice.remove(at: at)
          session.toggleTile(position)
        }
      }
    }
    session.check()
  } else {
    let index = exercise.choices.indices.first { exercise.isChoiceCorrect($0) == true }
      ?? exercise.choices.indices.first { Exercises.grade(exercise, answer: .choice($0), analyzer: analyzer).correct }
      ?? 0
    session.select(choice: index)
    if session.phase == .answering { session.check() }
  }
}

@MainActor
private func answerWrong(_ session: LessonSession) {
  guard let exercise = session.exercise else { return }
  let index = exercise.choices.indices.first { exercise.isChoiceCorrect($0) == false } ?? 0
  session.select(choice: index)
  if session.phase == .answering { session.check() }
}

@MainActor
struct LessonSessionTests {
  private func session(_ id: String, seed: UInt64 = 5, gold: Bool = false, intro: Bool = false) -> LessonSession {
    LessonSession(node: Curriculum.node(id: id)!, gold: gold, seed: seed, showIntro: intro)
  }

  @Test func aPerfectLessonFinishesWithThreeStars() {
    let s = session("u1l1")
    #expect(s.phase == .answering && s.total == 8 && s.progress == 0)
    var guardCount = 0
    while s.phase != .finished && guardCount < 40 {
      answerRight(s)
      #expect(s.phase == .feedback && s.feedback?.correct == true)
      s.next()
      guardCount += 1
    }
    #expect(s.phase == .finished && s.records.count == 8 && s.progress == 1)
    let result = s.playResult(day: today, hour: 9)
    #expect(LessonScoring.stars(result.records) == 3)
    #expect(s.bestCombo == 8 && s.xpEarned == 85)
  }

  @Test func aMistakeComesBackOnceAtTheEnd() {
    let s = session("u1l1")
    answerWrong(s)
    #expect(s.feedback?.correct == false && s.feedback?.correctAnswer.isEmpty == false)
    #expect(s.total == 9, "one re-asked question joins the end")
    s.next()
    while s.index < 8 { answerRight(s); s.next() }
    #expect(s.isReask && s.phase == .answering)
    answerWrong(s)  // wrong again: not asked a third time
    #expect(s.total == 9)
    s.next()
    #expect(s.phase == .finished)
    let records = s.records
    #expect(records.filter(\.isReask).count == 1 && records.filter { !$0.correct }.count == 2)
    #expect(LessonScoring.stars(records) == 2)
    // The re-asked question is a new one of the same type and difficulty.
    #expect(records[0].exercise != records[8].exercise && records[0].exercise.type == records[8].exercise.type)
  }

  @Test func checkpointsDoNotReaskAndHaveNoHints() {
    let s = session("u1c")
    #expect(s.total == 10 && !s.hintsAllowed && !s.hintAvailable)
    answerWrong(s)
    #expect(s.total == 10)
    #expect(!session("u1l1", gold: true).hintsAllowed)
    #expect(session("u1l1").hintsAllowed)
  }

  @Test func aHintCostsTheThirdStarAndPaysLess() {
    let s = session("u1l1")
    #expect(s.hintAvailable)
    s.useHint()
    #expect(!s.hintAvailable && s.hint != nil)
    #expect(s.removedChoices.count >= 1)
    answerRight(s)
    #expect(s.records[0].usedHint && s.feedback?.xp == 5)
    s.next()
    #expect(s.hint == nil && s.hintAvailable, "one hint per question")
    #expect(LessonScoring.stars([s.records[0]]) == 2)
  }

  @Test func aRemovedChoiceCannotBePicked() {
    let s = session("u1l1")
    s.useHint()
    let removed = s.removedChoices.first!
    s.select(choice: removed)
    #expect(s.choice == nil && !s.canCheck)
  }

  @Test func yesNoQuestionsCommitOnTap() {
    let s = LessonSession(node: Curriculum.node(id: "u2l3")!, seed: 5, showIntro: false)
    var seenYesNo = false
    for _ in 0..<8 {
      if s.commitsOnTap {
        seenYesNo = true
        s.select(choice: 0)
        #expect(s.phase == .feedback)
      } else {
        answerRight(s)
      }
      s.next()
    }
    #expect(seenYesNo)
  }

  @Test func keepOrPassCommitsAfterFiveDecisions() {
    let node = Curriculum.node(id: "u6l2")!
    let s = LessonSession(node: node, seed: 3, showIntro: false)
    #expect(s.exercise?.id.type == .keepOrPass && s.commitsOnTap && !s.canCheck)
    let exercise = s.exercise!
    for index in 0..<4 {
      s.decide(keep: exercise.shouldKeep(queueIndex: index) ?? true)
      #expect(s.phase == .answering && s.decisionMarks.count == index + 1)
    }
    s.decide(keep: !(exercise.shouldKeep(queueIndex: 4) ?? true))
    #expect(s.phase == .feedback && s.feedback?.correct == false)
    #expect(s.decisionMarks == [true, true, true, true, false])
  }

  @Test func selectingTilesRespectsTheCountAndJokers() {
    // Unit 6 lesson 4 is passOne at difficulty 3, which holds a joker.
    var found: LessonSession?
    for seed in UInt64(1)...30 {
      let s = LessonSession(node: Curriculum.node(id: "u8l2")!, seed: seed, showIntro: false)
      if s.exercise?.tiles.contains(.joker) == true { found = s; break }
    }
    let s = found!
    let exercise = s.exercise!
    let joker = exercise.tiles.firstIndex(of: .joker)!
    s.toggleTile(joker)
    #expect(s.selectedTiles.isEmpty && s.message == "Jokers can't be passed" && s.jokerShakes == 1)
    let others = exercise.tiles.indices.filter { $0 != joker }
    s.toggleTile(others[0]); s.toggleTile(others[1]); s.toggleTile(others[2])
    #expect(s.selectedTiles.count == 3 && s.canCheck)
    s.toggleTile(others[3])
    #expect(s.selectedTiles.count == 3 && s.message != nil)
    s.toggleTile(others[0])
    #expect(s.selectedTiles.count == 2 && !s.canCheck)
  }

  @Test func theIntroComesFirstOnlyWhenAsked() {
    let first = session("u1l1", intro: true)
    #expect(first.phase == .intro && first.exercise == nil)
    first.begin()
    #expect(first.phase == .answering && first.exercise != nil)
    #expect(session("u1l1", intro: false).phase == .answering)
    #expect(LessonSession(node: Curriculum.node(id: "u1c")!, seed: 1, showIntro: true).phase == .answering)
  }

  @Test func theSameSeedAsksTheSameQuestions() {
    let a = session("u4l2", seed: 9)
    let b = session("u4l2", seed: 9)
    #expect(a.items == b.items && a.exercise?.tiles == b.exercise?.tiles)
    #expect(session("u4l2", seed: 10).items != a.items)
  }

  @Test func everyKindOfQuestionCanBeAnsweredAndFinishes() {
    // One play of each node's first lesson of every unit, solved through the session.
    for node in ["u2l4", "u3l2", "u4l1", "u4l3", "u5l1", "u6l1", "u8l1", "u9l1"] {
      let s = LessonSession(node: Curriculum.node(id: node)!, seed: 2, showIntro: false)
      var steps = 0
      while s.phase != .finished && steps < 30 {
        answerRight(s)
        #expect(s.phase == .feedback, "\(node) step \(steps)")
        s.next()
        steps += 1
      }
      #expect(s.phase == .finished, "\(node)")
      #expect(s.records.allSatisfy { $0.correct }, "\(node)")
    }
  }
}

@MainActor
struct PracticeStoreTests {
  @Test func fileHoldsVersionAndFlatFields() throws {
    let directory = makeTempDirectory()
    let store = PracticeStore(directory: directory, persistDelay: fast, clock: .fixed(today))
    store.update { $0.xp = 42 }
    store.flush()
    let data = try Data(contentsOf: directory.appendingPathComponent("practice.json"))
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["version"] as? Int == 1 && json["xp"] as? Int == 42)
    #expect(json["lessons"] != nil && json["streak"] != nil && json["freePlay"] != nil)
  }

  @Test func applyingAPlaySavesRightAway() {
    let directory = makeTempDirectory()
    let store = PracticeStore(directory: directory, persistDelay: fast, clock: .fixed(today))
    let s = LessonSession(node: Curriculum.node(id: "u1l1")!, seed: 1, showIntro: false)
    for _ in 0..<8 { answerRight(s); s.next() }
    let outcome = store.apply(s.playResult(day: store.today, hour: store.hour))
    #expect(outcome?.stars == 3)
    let reloaded = PracticeStore(directory: directory, persistDelay: fast)
    #expect(reloaded.progress == store.progress)
    #expect(reloaded.progress.lessons["u1l1"]?.stars == 3)
    #expect(reloaded.progress.nextNode?.spec.id == "u1l2")
  }

  @Test func bestStreaksMoveHereOnceFromSettings() {
    let directory = makeTempDirectory()
    let store = PracticeStore(directory: directory, persistDelay: fast)
    #expect(!store.loadedFromFile)
    store.importBestStreaks(BestStreaks(pickAHand: 7, charleston: 3))
    #expect(store.progress.freePlay.pickStreakBest == 7 && store.progress.freePlay.charlestonStreakBest == 3)
    store.setBestStreak(pickAHand: 2)
    #expect(store.progress.freePlay.pickStreakBest == 7)
    store.flush()
    let again = PracticeStore(directory: directory, persistDelay: fast)
    #expect(again.loadedFromFile)
    again.importBestStreaks(BestStreaks(pickAHand: 99, charleston: 99))
    #expect(again.progress.freePlay.pickStreakBest == 7, "an existing file wins over old settings")
  }

  @Test func appStoresMigrateAndResetPractice() {
    let directory = makeTempDirectory()
    let settings = SettingsStore(directory: directory, persistDelay: fast)
    settings.setBestStreak(pickAHand: 5, charleston: 4)
    settings.flush()
    let stores = AppStores(directory: directory, persistDelay: fast)
    #expect(stores.practice.progress.freePlay.pickStreakBest == 5)
    #expect(stores.settings.settings.bestStreaks == BestStreaks())
    stores.practice.update { $0.xp = 10 }
    stores.resetAllData()
    #expect(stores.practice.progress == PracticeProgress())
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func resetClearsOnlyPractice() {
    let stores = AppStores.inMemory(persistDelay: fast)
    stores.settings.update { $0.assistLevel = .coach }
    stores.practice.update { $0.xp = 10 }
    stores.practice.reset()
    #expect(stores.practice.progress == PracticeProgress() && stores.settings.settings.assistLevel == .coach)
  }

  @Test func placementPicksTheStartTab() {
    let store = PracticeStore(directory: makeTempDirectory(), persistDelay: fast)
    store.applyPlacement(.regular)
    #expect(store.startTab == .game && store.progress.nextNode?.spec.id == "u7l1")
    let fresh = PracticeStore(directory: makeTempDirectory(), persistDelay: fast)
    fresh.applyPlacement(.new)
    #expect(fresh.startTab == .practice && fresh.progress.nextNode?.spec.id == "u1l1")
    let basics = PracticeStore(directory: makeTempDirectory(), persistDelay: fast)
    basics.applyPlacement(.basics)
    #expect(basics.startTab == .practice && basics.progress.nextNode?.spec.id == "u4l1")
  }

  @Test func openingTheDayAfterABreakQueuesAMessage() {
    let directory = makeTempDirectory()
    let early = PracticeStore(directory: directory, persistDelay: fast, clock: .fixed(today))
    early.update { $0.streak.current = 3; $0.streak.longest = 3; $0.streak.lastDay = today; $0.streak.daysPlayed = 3 }
    early.flush()
    let later = PracticeStore(directory: directory, persistDelay: fast, clock: .fixed(today.adding(days: 5)))
    later.openDay()
    #expect(later.pendingStreakEvents == [.streakLost(previous: 3, daysPlayed: 3)])
    #expect(later.progress.streak.current == 0)
  }

  @Test func launchArgumentsParse() {
    #expect(LaunchOptions.practiceSeed(arguments: ["-UITestResetData", "-UITestPracticeSeed", "7"]) == 7)
    #expect(LaunchOptions.practiceSeed(arguments: ["-UITestPracticeSeed", "7"]) == nil)
    #expect(LaunchOptions.placement(arguments: ["-UITestResetData", "-UITestPlacement", "basics"]) == .basics)
    let clock = LaunchOptions.practiceClock(arguments: ["-UITestResetData", "-UITestToday", "2026-11-02", "-UITestHour", "7"])
    #expect(clock.now().day == today && clock.now().hour == 7)
    #expect(LaunchOptions.initialTab(arguments: ["-UITestResetData", "-UITestTab", "practice"]) == .practice)
    #expect(
      LaunchOptions.dayLog(arguments: ["-UITestResetData", "-UITestDayLog", "2026-10-31,2026-10-30,nope"])
        == [LocalDay(year: 2026, month: 10, day: 30), LocalDay(year: 2026, month: 10, day: 31)])
    #expect(LaunchOptions.freezes(arguments: ["-UITestResetData", "-UITestFreezes", "2"]) == 2)
    #expect(LaunchOptions.dailyGoal(arguments: ["-UITestResetData", "-UITestDailyGoal", "serious"]) == .serious)
    #expect(LaunchOptions.dayLog(arguments: ["-UITestDayLog", "2026-10-31"]).isEmpty)
  }

  @Test func injectedDaysBuildAStreakAndAGoal() {
    let store = PracticeStore(directory: makeTempDirectory(), persistDelay: fast, clock: .fixed(today))
    store.update {
      $0.dailyGoal = .regular
      for n in (1...7).reversed() { $0.recordDay(today.adding(days: -n)) }
    }
    #expect(store.progress.streak.current == 7, "\(store.progress.streak)")
    #expect(store.progress.streak.freezes == 1, "\(store.progress.streak)")
    #expect(store.progress.lessonsPlayed(on: today.adding(days: -3)) == 2)
    #expect(store.progress.goalMet(on: today.adding(days: -3)))
  }
}

@MainActor
struct FeelTests {
  private func outcome(_ build: (inout PlayOutcome) -> Void) -> PlayOutcome {
    var o = PlayOutcome(node: Curriculum.node(id: "u1l1"))
    build(&o)
    return o
  }

  @Test func celebrationsComeInOrderAndOnlyWhenEarned() {
    #expect(Celebrations.items(for: outcome { _ in }).isEmpty)
    let full = outcome {
      $0.levelUp = Levels.position(totalXP: 130)
      $0.newBadges = [.firstSteps, .earlyBird]
      $0.goalJustMet = true
      $0.streakEvents = [.goalMet, .streakGrew(to: 3), .milestone(3)]
    }
    #expect(
      Celebrations.items(for: full) == [
        .levelUp(level: 2, title: "Newcomer"), .badge(.firstSteps), .badge(.earlyBird), .milestone(days: 3),
      ])
    let goalOnly = outcome {
      $0.goalJustMet = true
      $0.streakEvents = [.goalMet, .streakGrew(to: 4)]
    }
    #expect(Celebrations.items(for: goalOnly) == [.goalMet(streak: 4)])
    let freeze = outcome { $0.streakEvents = [.streakGrew(to: 7), .freezeEarned(held: 1), .milestone(7)] }
    #expect(Celebrations.items(for: freeze) == [.milestone(days: 7), .freezeEarned(held: 1)])
  }

  @Test func everySoundIsBundledAndUnderAHalfSecondOrSo() throws {
    for sound in Sound.allCases {
      let url = try #require(Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"), "\(sound)")
      let player = try AVAudioPlayer(contentsOf: url)
      #expect(player.duration > 0.05 && player.duration < 0.6, "\(sound) \(player.duration)")
    }
  }

  @Test func soundAndSpeedSettingsDefaultAndPersist() {
    let directory = makeTempDirectory()
    let store = SettingsStore(directory: directory, persistDelay: fast)
    #expect(store.settings.soundEffects && !store.settings.speedRoundNoTimer)
    store.update { $0.soundEffects = false; $0.speedRoundNoTimer = true }
    store.flush()
    let again = SettingsStore(directory: directory, persistDelay: fast)
    #expect(!again.settings.soundEffects && again.settings.speedRoundNoTimer)
  }

  @Test func levelsAreCelebratedOncePerLevel() {
    var p = PracticeProgress()
    p.xp = 99
    let up = p.apply(PlayResult(nodeID: "u1l1", records: (0..<8).map { AnswerRecord(exercise: ExerciseID(type: .tileFact, seed: UInt64($0), difficulty: 1), correct: true) }, day: today))
    #expect(Celebrations.items(for: up!).contains(.levelUp(level: 3, title: "Tile Spotter")))
  }
}

@MainActor
struct Phase29Tests {
  @Test func everySingleChoiceCommitsOnTapAndSelectionsKeepCheck() {
    var commits = 0
    var keeps = 0
    for type in ExerciseType.allCases {
      let id = ExerciseID(type: type, seed: 3, difficulty: 2)
      let session = LessonSession(title: "t", ids: [id], seed: 1)
      guard let exercise = session.exercise else { continue }
      if exercise.selectCount > 0 {
        #expect(!session.commitsOnTap, "\(type) keeps Check")
        keeps += 1
      } else if !exercise.choices.isEmpty || type == .keepOrPass {
        #expect(session.commitsOnTap, "\(type) commits on tap")
        commits += 1
      }
    }
    #expect(commits >= 8 && keeps == 2)
  }

  @Test func tappingAChoiceChecksAtOnce() {
    let session = LessonSession(title: "t", ids: [ExerciseID(type: .tileFact, seed: 3, difficulty: 1)], seed: 1)
    session.select(choice: 0)
    #expect(session.phase == .feedback && session.grade != nil)
  }

  @Test func cheatSheetListsEveryGroupAndOnlyShowsBlanksWhenOn() {
    let off = TileCheatSheet.groups(blanks: false).map(\.heading)
    #expect(off == ["Suits", "Winds", "Dragons", "Flowers", "Jokers", "Sets"])
    #expect(TileCheatSheet.groups(blanks: true).map(\.heading).contains("Blanks"))
    let dragons = TileCheatSheet.groups(blanks: false).first { $0.id == "dragons" }!
    #expect(dragons.rows.first { $0.name == "Green Dragon" }?.spoken == "Green Dragon. Goes with Bams. 4 in a set.")
    let sets = TileCheatSheet.groups(blanks: false).first { $0.id == "sets" }!
    #expect(sets.rows.map(\.tiles.count) == [1, 2, 3, 4, 5, 6])
  }

  @Test func theTileGuideAndTheCheatSheetShareTheirFacts() {
    for fact in TileCheatSheet.suits {
      let found = LearnTiles.topic.sections.flatMap(\.blocks).contains { block in
        if case .table(_, let rows) = block { return rows.contains { $0.first == fact.name && $0.contains(fact.alsoCalled) } }
        return false
      }
      #expect(found, "\(fact.name) is in both")
    }
  }

  @Test func theCheatSheetIsHiddenInGoldLessonsAndTheScoredDeal() {
    let gold = LessonSession(node: Curriculum.node(id: "u1l1")!, gold: true, seed: 1, showIntro: false)
    #expect(!gold.cheatSheetAllowed)
    let normal = LessonSession(node: Curriculum.node(id: "u1l1")!, seed: 1, showIntro: false)
    #expect(normal.cheatSheetAllowed)
    let analyzer = Analyzer.cached(for: PracticeCard.card)
    let scored = DailyDealPlay(day: today, analyzer: analyzer, scored: true).session()
    #expect(!scored.cheatSheetAllowed)
    let replay = DailyDealPlay(day: today, analyzer: analyzer, scored: false).session()
    #expect(replay.cheatSheetAllowed)
  }

  @Test func todaysDealDifficultyFollowsTheWeekday() {
    #expect((1...7).map(TodaysDealNode.difficulty(isoWeekday:)) == [1, 1, 1, 2, 2, 3, 3])
  }
}
