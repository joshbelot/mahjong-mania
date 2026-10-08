import MahjongCore
import Observation
import SwiftUI

enum AssistLevel: String, Codable, CaseIterable, Sendable {
  case off, peek, coach

  var title: String {
    switch self {
    case .off: return "Off"
    case .peek: return "Peek"
    case .coach: return "Coach"
    }
  }
}

enum AppTheme: String, Codable, CaseIterable, Sendable {
  case system, light, dark

  var title: String { rawValue.capitalized }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

enum TileSort: String, Codable, CaseIterable, Sendable {
  case suit, entered

  var title: String {
    switch self {
    case .suit: return "By suit"
    case .entered: return "As entered"
    }
  }
}

struct BestStreaks: Codable, Hashable, Sendable {
  var pickAHand = 0
  var charleston = 0
}

struct AppSettings: VersionedDocument, Equatable {
  static let currentVersion = 1
  static let practiceCardID = "practice-v1"

  var version = AppSettings.currentVersion
  var assistLevel: AssistLevel = .peek
  var theme: AppTheme = .system
  var haptics = true
  var keepAwake = true
  var tileSort: TileSort = .suit
  var defaultRules: RuleSet = .standard
  var savedRules: [RuleSet] = []
  var onboardingDone = false
  var activeCardID = AppSettings.practiceCardID
  var cardNoticeSeen = false
  var bestStreaks = BestStreaks()

  init() {}

  /// Every key is optional so files written by older versions keep loading when fields are added.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    assistLevel = try c.decodeIfPresent(AssistLevel.self, forKey: .assistLevel) ?? .peek
    theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
    haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
    keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? true
    tileSort = try c.decodeIfPresent(TileSort.self, forKey: .tileSort) ?? .suit
    defaultRules = try c.decodeIfPresent(RuleSet.self, forKey: .defaultRules) ?? .standard
    savedRules = try c.decodeIfPresent([RuleSet].self, forKey: .savedRules) ?? []
    onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
    activeCardID = try c.decodeIfPresent(String.self, forKey: .activeCardID) ?? Self.practiceCardID
    cardNoticeSeen = try c.decodeIfPresent(Bool.self, forKey: .cardNoticeSeen) ?? false
    bestStreaks = try c.decodeIfPresent(BestStreaks.self, forKey: .bestStreaks) ?? BestStreaks()
  }
}

@MainActor
@Observable
final class SettingsStore {
  private(set) var settings: AppSettings
  @ObservationIgnored private let persister: Persister<AppSettings>

  init(directory: URL, persistDelay: Duration = .milliseconds(300)) {
    let file = JSONFileStore<AppSettings>(directory: directory, name: "settings")
    settings = file.load() ?? AppSettings()
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in self?.settings }
  }

  func update(_ change: (inout AppSettings) -> Void) {
    var copy = settings
    change(&copy)
    guard copy != settings else { return }
    settings = copy
    persister.changed()
  }

  /// A binding to one setting, for use in forms.
  func binding<Value: Sendable>(_ keyPath: WritableKeyPath<AppSettings, Value> & Sendable) -> Binding<Value> {
    Binding(
      get: { MainActor.assumeIsolated { self.settings[keyPath: keyPath] } },
      set: { newValue in MainActor.assumeIsolated { self.update { $0[keyPath: keyPath] = newValue } } })
  }

  func setBestStreak(pickAHand: Int? = nil, charleston: Int? = nil) {
    update {
      if let pickAHand { $0.bestStreaks.pickAHand = max($0.bestStreaks.pickAHand, pickAHand) }
      if let charleston { $0.bestStreaks.charleston = max($0.bestStreaks.charleston, charleston) }
    }
  }

  func flush() { persister.flush() }

  /// Back to factory settings (onboarding will run again).
  func reset() {
    persister.removeFile()
    settings = AppSettings()
  }

  var writeCount: Int { persister.writeCount }
}
