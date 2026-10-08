import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)

private func win(_ winner: String, from discarder: String? = nil, points: Int = 25) -> HandKind {
  .mahjong(MahjongInput(winnerID: winner, discarderID: discarder, basePoints: points))
}

@MainActor
struct SettingsStoreTests {
  @Test func updatesPersistAndReload() {
    let directory = makeTempDirectory()
    let store = SettingsStore(directory: directory, persistDelay: fast)
    #expect(store.settings == AppSettings())
    store.update {
      $0.assistLevel = .coach
      $0.theme = .dark
      $0.haptics = false
      $0.activeCardID = "mine"
      $0.defaultRules.selfPickMultiplier = 3
    }
    store.setBestStreak(pickAHand: 4, charleston: 2)
    store.setBestStreak(pickAHand: 1)
    store.flush()
    let reloaded = SettingsStore(directory: directory, persistDelay: fast)
    #expect(reloaded.settings == store.settings)
    #expect(reloaded.settings.assistLevel == .coach)
    #expect(reloaded.settings.bestStreaks == BestStreaks(pickAHand: 4, charleston: 2))
  }

  @Test func missingKeysFallBackToDefaults() throws {
    let directory = makeTempDirectory()
    try Data("{\"version\":1,\"assistLevel\":\"coach\"}".utf8).write(
      to: directory.appendingPathComponent("settings.json"))
    let store = SettingsStore(directory: directory, persistDelay: fast)
    #expect(store.settings.assistLevel == .coach)
    #expect(store.settings.keepAwake)
    #expect(store.settings.activeCardID == "practice-v1")
    #expect(store.settings.defaultRules == .standard)
  }

  @Test func unchangedUpdatesDoNotWrite() {
    let store = SettingsStore(directory: makeTempDirectory(), persistDelay: fast)
    store.update { $0.haptics = true }
    store.flush()
    #expect(store.writeCount == 0)
  }

  @Test func resetReturnsToDefaultsAndDeletesTheFile() {
    let directory = makeTempDirectory()
    let store = SettingsStore(directory: directory, persistDelay: fast)
    store.update { $0.onboardingDone = true }
    store.flush()
    #expect(files(in: directory) == ["settings.json"])
    store.reset()
    #expect(store.settings == AppSettings())
    #expect(files(in: directory).isEmpty)
  }

  @Test func bindingsReadAndWrite() {
    let store = SettingsStore(directory: makeTempDirectory(), persistDelay: fast)
    let binding = store.binding(\.keepAwake)
    #expect(binding.wrappedValue)
    binding.wrappedValue = false
    #expect(!store.settings.keepAwake)
  }
}

@MainActor
struct PlayersStoreTests {
  @Test func addsPlayersWithDistinctColoursAndPersists() {
    let directory = makeTempDirectory()
    let store = PlayersStore(directory: directory, persistDelay: fast)
    let a = store.add(name: "  Alex ", id: "a", at: Date(timeIntervalSince1970: 1))
    let b = store.add(name: "Bea", id: "b", at: Date(timeIntervalSince1970: 2))
    let c = store.add(name: "Cy", id: "c", at: Date(timeIntervalSince1970: 3))
    #expect(a.name == "Alex")
    #expect([a, b, c].map(\.colorIndex) == [0, 1, 2])
    store.rename(id: b.id, to: "Beatrice")
    store.setColor(id: c.id, index: 7)
    store.flush()
    let reloaded = PlayersStore(directory: directory, persistDelay: fast)
    #expect(reloaded.players == store.players)
    #expect(reloaded.player(id: b.id)?.name == "Beatrice")
    #expect(reloaded.player(id: c.id)?.colorIndex == 7)
  }

  @Test func archivedPlayersFreeTheirColour() {
    let store = PlayersStore(directory: makeTempDirectory(), persistDelay: fast)
    let a = store.add(name: "A")
    _ = store.add(name: "B")
    store.setArchived(id: a.id, true)
    #expect(store.activePlayers.map(\.name) == ["B"])
    #expect(store.archivedPlayers.map(\.name) == ["A"])
    #expect(store.add(name: "C").colorIndex == 0)
    store.setArchived(id: a.id, false)
    #expect(store.activePlayers.count == 3)
  }

  @Test func unknownIDsAreIgnored() {
    let store = PlayersStore(directory: makeTempDirectory(), persistDelay: fast)
    store.rename(id: "nope", to: "x")
    store.setArchived(id: "nope", true)
    #expect(store.players.isEmpty)
  }
}

@MainActor
struct SessionsStoreTests {
  private func start(_ store: SessionsStore, id: String = "s1") -> Session {
    store.start(seatIDs: ["A", "B", "C", "D"], cardID: "practice-v1", rules: .standard, id: id, at: Date(timeIntervalSince1970: 1_000))
  }

  @Test func sessionLifecycleAndPersistence() throws {
    let directory = makeTempDirectory()
    let store = SessionsStore(directory: directory, persistDelay: fast)
    #expect(store.activeSession == nil)
    let session = start(store)
    #expect(store.activeSession?.id == session.id)
    store.addHand(win("A", from: "B"), to: "s1", id: "h1", at: Date(timeIntervalSince1970: 1_100))
    store.addHand(.wall(note: nil), to: "s1", id: "h2", at: Date(timeIntervalSince1970: 1_200))
    store.flush()

    let reloaded = SessionsStore(directory: directory, persistDelay: fast)
    #expect(reloaded.sessions == store.sessions)
    #expect(reloaded.activeSession?.hands.count == 2)
    let active = try #require(reloaded.activeSession)
    #expect(Scoring.totals(active)["A"] == 100)

    reloaded.end(sessionID: "s1", at: Date(timeIntervalSince1970: 2_000))
    #expect(reloaded.activeSession == nil)
    #expect(reloaded.finishedSessions.map(\.id) == ["s1"])
    reloaded.reopen(sessionID: "s1")
    #expect(reloaded.activeSession?.id == "s1")
  }

  @Test func editUndoRemoveAndRules() {
    let store = SessionsStore(directory: makeTempDirectory(), persistDelay: fast)
    _ = start(store)
    store.addHand(win("A", from: "B"), to: "s1", id: "h1")
    store.addHand(win("C"), to: "s1", id: "h2")
    store.editHand(id: "h1", to: win("A", from: "B", points: 50), in: "s1")
    #expect(Scoring.totals(store.session(id: "s1")!)["A"] == 200 - 50)
    store.undoLast(in: "s1")
    #expect(store.session(id: "s1")?.hands.map(\.id) == ["h1"])
    var rules = RuleSet.standard
    rules.discarderMultiplier = 1
    store.setRules(rules, in: "s1")
    #expect(store.session(id: "s1")?.hands[0].payments["B"] == -50)
    store.removeHand(id: "h1", from: "s1")
    #expect(store.session(id: "s1")?.hands.isEmpty == true)
  }

  @Test func startingANewSessionEndsTheActiveOne() {
    let store = SessionsStore(directory: makeTempDirectory(), persistDelay: fast)
    _ = start(store, id: "old")
    _ = store.start(seatIDs: ["A", "B", "C"], cardID: nil, rules: .standard, id: "new")
    #expect(store.activeSession?.id == "new")
    #expect(store.session(id: "old")?.endedAt != nil)
  }

  @Test func deleteAndUnknownIDs() {
    let store = SessionsStore(directory: makeTempDirectory(), persistDelay: fast)
    _ = start(store)
    store.addHand(win("A"), to: "missing")
    store.delete(sessionID: "s1")
    #expect(store.sessions.isEmpty)
    #expect(store.activeSessionID == nil)
  }
}

@MainActor
struct CardsStoreTests {
  private let text = "! Mine\nNNNN EEE WWW SSSS ; 25 ; X ; Winds\nFF 2222 ; 25 ; X ; Broken\n"

  @Test func practiceCardIsAlwaysFirstAndNeverPersisted() {
    let directory = makeTempDirectory()
    let store = CardsStore(directory: directory, persistDelay: fast)
    #expect(store.cards.map(\.id) == ["practice-v1"])
    #expect(store.card(id: "practice-v1")?.lines.count == 37)
    store.flush()
    #expect(files(in: directory).isEmpty)
  }

  @Test func createParsesPersistsAndReloads() {
    let directory = makeTempDirectory()
    let store = CardsStore(directory: directory, persistDelay: fast)
    let record = store.createCard(name: "Mine", text: text, id: "c1", at: Date(timeIntervalSince1970: 10))
    let card = store.card(id: "c1")
    #expect(card?.name == "Mine")
    #expect(card?.lines.count == 1)
    #expect(card?.builtIn == false)
    #expect(store.problems(in: "c1").count == 1)
    store.flush()
    let reloaded = CardsStore(directory: directory, persistDelay: fast)
    #expect(reloaded.records == [record])
    #expect(reloaded.card(id: "c1")?.lines.map(\.name) == ["Winds"])
  }

  @Test func parsedCardIsCachedUntilUpdatedAtChanges() {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    store.createCard(name: "Mine", text: text, id: "c1", at: Date(timeIntervalSince1970: 10))
    _ = store.card(id: "c1")
    _ = store.card(id: "c1")
    _ = store.cards
    #expect(store.parseCount == 1)
    store.updateText(id: "c1", text: "! Mine\nNNNN EEE WWW SSSS ; 30 ; X ; Winds\n", at: Date(timeIntervalSince1970: 20))
    #expect(store.card(id: "c1")?.lines.first?.points == 30)
    #expect(store.parseCount == 2)
  }

  @Test func analyzerIsCachedPerCardVersion() throws {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    store.createCard(name: "Mine", text: text, id: "c1", at: Date(timeIntervalSince1970: 10))
    let first = try #require(store.analyzer(for: "c1"))
    #expect(store.analyzer(for: "c1") === first)
    store.updateText(id: "c1", text: text, at: Date(timeIntervalSince1970: 11))
    #expect(try #require(store.analyzer(for: "c1")) !== first)
    #expect(store.analyzer(for: "practice-v1")?.card.lines.count == 37)
    #expect(store.analyzer(for: "nope") == nil)
  }

  @Test func duplicateTheBuiltInCard() {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    let copy = store.duplicate(cardID: "practice-v1", id: "copy")
    #expect(copy?.name == "Practice Card copy")
    let card = store.card(id: "copy")
    #expect(card?.lines.count == 37)
    #expect(card?.year == 2026)
    #expect(card?.lines.map(\.source) == PracticeCard.card.lines.map(\.source))
    #expect(store.duplicate(cardID: "nope") == nil)
  }

  @Test func renameRewritesTheHeaderAndKeepsBrokenLines() {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    store.createCard(name: "Mine", text: text, id: "c1")
    store.rename(id: "c1", to: "Renamed")
    let record = store.record(id: "c1")
    #expect(record?.name == "Renamed")
    #expect(record?.text.hasPrefix("! Renamed\n") == true)
    #expect(record?.text.contains("FF 2222 ; 25 ; X ; Broken") == true)
    #expect(store.card(id: "c1")?.name == "Renamed")
    // No header yet: one is added.
    #expect(CardsStore.replacingHeaderName(in: "NNNN EEE WWW SSSS ; 25 ; X", with: "N") == "! N\nNNNN EEE WWW SSSS ; 25 ; X")
    // The year line is not mistaken for the name.
    #expect(CardsStore.replacingHeaderName(in: "!year 2026\n! Old", with: "New") == "!year 2026\n! New")
  }

  @Test func appendAndDelete() {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    store.createCard(name: "Mine", text: "! Mine", id: "c1")
    store.append(text: "# Extra\nNNNN EEE WWW SSSS ; 25 ; X ; Winds", to: "c1")
    #expect(store.card(id: "c1")?.lines.first?.section == "Extra")
    store.delete(id: "c1")
    #expect(store.card(id: "c1") == nil)
    #expect(store.records.isEmpty)
  }

  @Test func newCardGetsAHeader() {
    let store = CardsStore(directory: makeTempDirectory(), persistDelay: fast)
    let record = store.createCard(name: "  Fresh ", year: 2027, id: "f")
    #expect(record.text == "! Fresh\n!year 2027\n")
    #expect(store.card(id: "f")?.year == 2027)
  }
}

@MainActor
struct HelperStoreTests {
  @Test func rackRespectsPhysicalCopies() {
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    for _ in 0..<4 { #expect(store.add(.wind(.north))) }
    #expect(!store.add(.wind(.north)))
    #expect(store.rack.count == 4)
    store.removeTile(at: 0)
    #expect(store.add(.wind(.north)))
    for _ in 0..<8 { #expect(store.add(.joker)) }
    #expect(!store.add(.joker))
  }

  @Test func exposuresAndSeenCountTowardsUsage() {
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    store.addExposure(Exposure(tiles: [.number(5, .dots), .number(5, .dots), .joker]))
    store.incrementSeen(.number(5, .dots))
    #expect(store.usage[.number(5, .dots)] == 3)
    #expect(store.usage[.joker] == 1)
    store.add(.number(5, .dots))
    #expect(!store.canAdd(.number(5, .dots)))
    store.incrementSeen(.number(5, .dots))
    #expect(store.seen[.number(5, .dots)] == 1)
    store.decrementSeen(.number(5, .dots))
    #expect(store.seen[.number(5, .dots)] == nil)
    store.decrementSeen(.number(5, .dots))
    #expect(store.canAdd(.number(5, .dots)))
  }

  @Test func everythingPersists() {
    let directory = makeTempDirectory()
    let store = HelperStore(directory: directory, persistDelay: fast)
    store.setMode(.playing)
    store.setRack([.number(1, .bams), .flower, .joker])
    store.addExposure(Exposure(tiles: [.wind(.east), .wind(.east), .wind(.east)]))
    store.incrementSeen(.dragon(.red))
    store.incrementSeen(.dragon(.red))
    store.pin(lineID: "L3_abc")
    store.addOpponentExposure(Exposure(tiles: [.number(6, .bams), .number(6, .bams), .number(6, .bams)]), at: 1)
    store.flush()

    let reloaded = HelperStore(directory: directory, persistDelay: fast)
    #expect(reloaded.mode == .playing)
    #expect(reloaded.rack == store.rack)
    #expect(reloaded.exposures == store.exposures)
    #expect(reloaded.seen == [.dragon(.red): 2])
    #expect(reloaded.pinnedLineID == "L3_abc")
    #expect(reloaded.opponents.map(\.label) == ["Right", "Across", "Left"])
    #expect(reloaded.opponents[1].exposures.count == 1)
    reloaded.removeOpponentExposure(at: 0, opponentIndex: 1)
    #expect(reloaded.opponents[1].exposures.isEmpty)
  }

  @Test func analysisIsMemoisedOnTheLastInput() {
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    let analyzer = Analyzer(card: PracticeCard.card)
    store.setRack([.number(2, .bams), .number(2, .bams), .number(2, .bams)])
    let first = store.results(using: analyzer)
    let second = store.results(using: analyzer)
    #expect(store.analysisCount == 1)
    #expect(first.map(\.line.id) == second.map(\.line.id))
    store.add(.number(4, .bams))
    _ = store.results(using: analyzer)
    #expect(store.analysisCount == 2)
    // Reordering the rack does not change the analysis input.
    store.setRack([.number(4, .bams), .number(2, .bams), .number(2, .bams), .number(2, .bams)])
    _ = store.results(using: analyzer)
    #expect(store.analysisCount == 2)
    store.incrementSeen(.wind(.north))
    _ = store.results(using: analyzer)
    #expect(store.analysisCount == 3)
  }

  @Test func clearAndReset() {
    let directory = makeTempDirectory()
    let store = HelperStore(directory: directory, persistDelay: fast)
    store.add(.flower)
    store.clearRack()
    #expect(store.rack.isEmpty)
    store.add(.flower)
    store.flush()
    store.reset()
    #expect(store.rack.isEmpty)
    #expect(store.mode == .charleston)
    #expect(files(in: directory).isEmpty)
  }
}

@MainActor
struct AppStoresTests {
  @Test func resetFirstWipesTheDirectoryAndSkipsOnboarding() {
    let directory = makeTempDirectory()
    let before = AppStores(directory: directory, persistDelay: fast)
    before.players.add(name: "Ghost")
    before.flush()
    #expect(files(in: directory).contains("players.json"))

    let after = AppStores(directory: directory, persistDelay: fast, resetFirst: true)
    #expect(after.players.players.isEmpty)
    #expect(after.settings.settings.onboardingDone)
  }

  @Test func resetAllDataClearsEverything() {
    let stores = AppStores.inMemory(persistDelay: fast)
    stores.players.add(name: "A")
    stores.settings.update { $0.onboardingDone = true; $0.assistLevel = .coach }
    stores.cards.createCard(name: "Mine")
    stores.helper.add(.flower)
    stores.sessions.start(seatIDs: ["A", "B", "C"], cardID: nil, rules: .standard)
    stores.flush()
    #expect(files(in: stores.directory).count == 5)

    stores.resetAllData()
    #expect(stores.players.players.isEmpty)
    #expect(stores.cards.records.isEmpty)
    #expect(stores.helper.rack.isEmpty)
    #expect(stores.sessions.sessions.isEmpty)
    #expect(stores.settings.settings == AppSettings())
    #expect(!FileManager.default.fileExists(atPath: stores.directory.path))
  }

  @Test func allStoresReloadFromDisk() {
    let first = AppStores.inMemory(persistDelay: fast)
    first.players.add(name: "A", id: "a")
    first.sessions.start(seatIDs: ["a"], cardID: nil, rules: .standard, id: "s")
    first.cards.createCard(name: "Mine", id: "c")
    first.helper.add(.joker)
    first.settings.update { $0.assistLevel = .off }
    first.flush()
    let second = AppStores(directory: first.directory, persistDelay: fast)
    #expect(second.players.players.map(\.id) == ["a"])
    #expect(second.sessions.activeSessionID == "s")
    #expect(second.cards.records.map(\.id) == ["c"])
    #expect(second.helper.rack == [.joker])
    #expect(second.settings.settings.assistLevel == .off)
  }
}
