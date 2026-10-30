import Foundation
import Observation

/// Owns the five stores and the data directory (`Application Support/MahjongMania`).
@MainActor
@Observable
final class AppStores {
  let directory: URL
  let settings: SettingsStore
  let players: PlayersStore
  let sessions: SessionsStore
  let cards: CardsStore
  let helper: HelperStore
  let practice: PracticeStore
  /// Plain names of the saved data that could not be read at launch and was set aside (SPEC §7.5, §19.4).
  var recovered: [String] = []

  /// `resetFirst` wipes the directory before loading (the `-UITestResetData` launch flag). A reset skips
  /// onboarding unless `showOnboarding` is set (the `-UITestShowOnboarding` launch flag).
  init(
    directory: URL, persistDelay: Duration = .milliseconds(300), resetFirst: Bool = false,
    showOnboarding: Bool = false
  ) {
    self.directory = directory
    let launchTime = Date()
    if resetFirst { try? FileManager.default.removeItem(at: directory) }
    settings = SettingsStore(directory: directory, persistDelay: persistDelay)
    players = PlayersStore(directory: directory, persistDelay: persistDelay)
    sessions = SessionsStore(directory: directory, persistDelay: persistDelay)
    cards = CardsStore(directory: directory, persistDelay: persistDelay)
    helper = HelperStore(directory: directory, persistDelay: persistDelay)
    practice = PracticeStore(directory: directory, persistDelay: persistDelay, clock: LaunchOptions.practiceClock())
    if !practice.loadedFromFile {
      practice.importBestStreaks(settings.settings.bestStreaks)
      settings.update { $0.bestStreaks = BestStreaks() }
    }
    if resetFirst && !showOnboarding { settings.update { $0.onboardingDone = true } }
    recovered = Self.recoveredData(in: directory, since: launchTime)
  }

  /// The kinds of saved data whose file was moved to `<name>.corrupt-<time>.json` since `date`.
  static func recoveredData(in directory: URL, since date: Date) -> [String] {
    let titles = [
      "settings": "settings", "players": "players", "sessions": "game nights", "cards": "your cards",
      "helper": "the Helper's rack", "practice": "practice progress",
    ]
    let cutoff = Int(date.timeIntervalSince1970 * 1000) - 1000
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    var found: [String] = []
    for file in names.sorted() {
      let parts = file.components(separatedBy: ".corrupt-")
      guard parts.count == 2, let stamp = Int(parts[1].replacingOccurrences(of: ".json", with: "")),
        stamp >= cutoff, let title = titles[parts[0]]
      else { continue }
      found.append(title)
    }
    return found
  }

  /// "Some saved data couldn't be read…": nil when nothing was recovered.
  var recoveredMessage: String? {
    guard !recovered.isEmpty else { return nil }
    let list = recovered.joined(separator: ", ")
    return "Some saved data couldn't be read, so it was set aside and the app started fresh for: \(list). Everything else is as you left it."
  }

  /// The app's real stores. `-UITestResetData` starts from an empty directory and skips onboarding;
  /// `-UITestShowOnboarding` starts from an empty directory and shows it.
  static func live() -> AppStores {
    let base =
      (try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? FileManager.default.temporaryDirectory
    let stores = AppStores(
      directory: base.appendingPathComponent("MahjongMania", isDirectory: true),
      resetFirst: LaunchOptions.resetData || LaunchOptions.showOnboarding,
      showOnboarding: LaunchOptions.showOnboarding)
    stores.applyHelperLaunchOptions()
    if let placement = LaunchOptions.placement() { stores.practice.applyPlacement(placement) }
    stores.practice.applyLaunchOptions()
    if LaunchOptions.speedNoTimer { stores.settings.update { $0.speedRoundNoTimer = true } }
    return stores
  }

  /// Stores backed by a fresh temporary directory (tests and previews).
  static func inMemory(persistDelay: Duration = .milliseconds(300)) -> AppStores {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MahjongManiaTests-\(UUID().uuidString)", isDirectory: true)
    return AppStores(directory: directory, persistDelay: persistDelay)
  }

  /// Writes any pending changes now (called when the app leaves the foreground).
  func flush() {
    settings.flush()
    players.flush()
    sessions.flush()
    cards.flush()
    helper.flush()
    practice.flush()
  }

  /// Settings → Reset all data: deletes every store file and returns to a first-launch state.
  func resetAllData() {
    settings.reset()
    players.reset()
    sessions.reset()
    cards.reset()
    helper.reset()
    practice.reset()
    try? FileManager.default.removeItem(at: directory)
  }
}
