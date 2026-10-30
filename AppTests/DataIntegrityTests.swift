import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

/// SPEC §19.4 step 3: older saved data loads with the same totals, and nothing is lost on the way.
@MainActor
struct DataIntegrityTests {
  private let fast = Duration.milliseconds(5)

  /// A `practice.json` as 1.2 wrote it: version 1, no `schema`, Unit 1 with four lessons. Built by encoding
  /// real progress and then undoing what 1.3 added.
  private func v12Practice() throws -> Data {
    var p = PracticeProgress()
    p.xp = 730
    p.speedBest = 14
    p.freePlay.pickStreakBest = 5
    p.counters.lessonsFinished = 9
    p.badges["firstSteps"] = LocalDay(year: 2026, month: 10, day: 10)
    p.streak.longest = 9
    p.units[1] = { var u = UnitProgress(); u.checkpointPassed = true; return u }()
    for (id, stars, plays) in [("u1l1", 3, 2), ("u1l2", 2, 1), ("u1l3", 3, 1), ("u1l4", 1, 1), ("u2l1", 3, 1)] {
      var l = LessonProgress()
      l.stars = stars
      l.plays = plays
      p.lessons[id] = l
    }
    p.dailyDeals["2026-10-17"] = DealRecord(pick: .best, pickDistance: 3, pass: [.green, .yellow, .red])
    p.reviewQueue.recordMiss(ExerciseID(type: .tileFact, seed: 9, difficulty: 1, focus: 2), today: LocalDay(year: 2026, month: 10, day: 18))
    var json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(PracticeDocument(progress: p))) as? [String: Any])
    json["schema"] = nil
    // 1.2 wrote the review queue's exercises with the old type names.
    var text = String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)
    text = text.replacingOccurrences(of: "\"tileFact\"", with: "\"findTile\"")
    return Data(text.utf8)
  }

  @Test func aV12PracticeFileLoadsWithTheSameTotalsAndMigratesUnitOne() throws {
    let directory = makeTempDirectory()
    try v12Practice().write(to: directory.appendingPathComponent("practice.json"))
    let store = PracticeStore(directory: directory, persistDelay: fast, clock: .fixed(LocalDay(year: 2026, month: 10, day: 19)))
    #expect(store.loadedFromFile)
    let p = store.progress
    #expect(p.xp == 730 && p.speedBest == 14 && p.streak.longest == 9 && p.freePlay.pickStreakBest == 5)
    #expect(p.badges["firstSteps"] != nil && p.dailyDeals.count == 1 && p.counters.lessonsFinished == 9)
    #expect(p.lessons["u1l1"]?.stars == 3 && p.lessons["u1l2"]?.stars == 3 && p.lessons["u1l3"]?.stars == 1)
    #expect(p.lessons["u1l4"] == nil && p.lessons["u2l1"]?.stars == 3)
    #expect(p.reviewQueue.items.first?.exercise.type == .tileFact)
    #expect(p.isUnitFinished(1))
    // Saved in the new shape, it reads back identically (and does not migrate twice).
    store.flush()
    store.update { $0.xp += 0 }
    store.flush()
    let again = PracticeStore(directory: directory, persistDelay: fast)
    #expect(again.progress == store.progress)
  }

  @Test func aV11SettingsFileKeepsEverythingAndGainsDefaults() throws {
    let directory = makeTempDirectory()
    var settings = AppSettings()
    settings.assistLevel = .coach
    settings.haptics = false
    settings.onboardingDone = true
    settings.tileStyle = .traditional
    var json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
    // 1.1 knew nothing of the sound setting, the Speed Round clock choice and the like.
    for key in ["soundEffects", "speedRoundNoTimer", "reduceMotion"] { json[key] = nil }
    try JSONSerialization.data(withJSONObject: json).write(to: directory.appendingPathComponent("settings.json"))
    let store = SettingsStore(directory: directory)
    #expect(store.settings.assistLevel == .coach && !store.settings.haptics && store.settings.onboardingDone)
    #expect(store.settings.tileStyle == .traditional)
    #expect(store.settings.defaultRules.rules.count >= RuleCatalog.builtIns.count)
    #expect(store.settings.soundEffects, "settings added later take their default")
    #expect(files(in: directory) == ["settings.json"], "nothing was quarantined")
  }

  @Test func resetAllDataReallyClearsEveryStore() {
    let directory = makeTempDirectory()
    let stores = AppStores(directory: directory, persistDelay: fast)
    _ = stores.players.add(name: "Ann")
    stores.practice.update { $0.xp = 99 }
    stores.settings.update { $0.haptics = false }
    stores.flush()
    stores.resetAllData()
    #expect(stores.players.players.isEmpty && stores.practice.progress.xp == 0)
    #expect(stores.settings.settings.haptics)
    let fresh = AppStores(directory: directory, persistDelay: fast)
    #expect(fresh.players.players.isEmpty && fresh.practice.progress.xp == 0)
  }

  @Test func aSaveNeverLeavesAHalfWrittenFile() throws {
    // Atomic writes: the file is either the old one or the new one, and no temporary files stay behind.
    let directory = makeTempDirectory()
    let store = PlayersStore(directory: directory, persistDelay: fast)
    for n in 0..<50 { _ = store.add(name: "P\(n)") }
    store.flush()
    let names = files(in: directory)
    #expect(names == ["players.json"], "\(names)")
    let data = try Data(contentsOf: directory.appendingPathComponent("players.json"))
    #expect((try? JSONSerialization.jsonObject(with: data)) != nil)
  }
}
