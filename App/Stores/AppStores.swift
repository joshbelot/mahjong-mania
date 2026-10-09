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

  /// `resetFirst` wipes the directory before loading (the `-UITestResetData` launch flag). A reset skips
  /// onboarding unless `showOnboarding` is set (the `-UITestShowOnboarding` launch flag).
  init(
    directory: URL, persistDelay: Duration = .milliseconds(300), resetFirst: Bool = false,
    showOnboarding: Bool = false
  ) {
    self.directory = directory
    if resetFirst { try? FileManager.default.removeItem(at: directory) }
    settings = SettingsStore(directory: directory, persistDelay: persistDelay)
    players = PlayersStore(directory: directory, persistDelay: persistDelay)
    sessions = SessionsStore(directory: directory, persistDelay: persistDelay)
    cards = CardsStore(directory: directory, persistDelay: persistDelay)
    helper = HelperStore(directory: directory, persistDelay: persistDelay)
    if resetFirst && !showOnboarding { settings.update { $0.onboardingDone = true } }
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
  }

  /// Settings → Reset all data: deletes every store file and returns to a first-launch state.
  func resetAllData() {
    settings.reset()
    players.reset()
    sessions.reset()
    cards.reset()
    helper.reset()
    try? FileManager.default.removeItem(at: directory)
  }
}
