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

/// How tiles are drawn everywhere in the app (SPEC §17.6).
enum TileStyle: String, Codable, CaseIterable, Sendable {
  case classic, traditional, largePrint, modern

  var title: String {
    switch self {
    case .classic: return "Classic"
    case .traditional: return "Traditional"
    case .largePrint: return "Large print"
    case .modern: return "Modern"
    }
  }

  var summary: String {
    switch self {
    case .classic: return "Clear numbers on ivory tiles. The way the app has always looked."
    case .traditional: return "Like a real set: Chinese numerals, pips and sticks, wind and dragon characters."
    case .largePrint: return "Big, bold numbers and letters with the suit spelled out. Easiest to read."
    case .modern: return "Flat colour: red, green and blue faces for the suits, with a simple shape for each."
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
  var tileStyle: TileStyle = .classic
  var defaultRules: RuleSet = .standard
  var savedRules: [RuleSet] = []
  var onboardingDone = false
  var activeCardID = AppSettings.practiceCardID
  var cardNoticeSeen = false
  var bestStreaks = BestStreaks()
  /// Short sounds in Practice (SPEC §18.7).
  var soundEffects = true
  /// Speed Round without the clock: 30 untimed questions (SPEC §18.8).
  var speedRoundNoTimer = false

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
    tileStyle = try c.decodeIfPresent(TileStyle.self, forKey: .tileStyle) ?? .classic
    defaultRules = try c.decodeIfPresent(RuleSet.self, forKey: .defaultRules) ?? .standard
    savedRules = try c.decodeIfPresent([RuleSet].self, forKey: .savedRules) ?? []
    onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
    activeCardID = try c.decodeIfPresent(String.self, forKey: .activeCardID) ?? Self.practiceCardID
    cardNoticeSeen = try c.decodeIfPresent(Bool.self, forKey: .cardNoticeSeen) ?? false
    bestStreaks = try c.decodeIfPresent(BestStreaks.self, forKey: .bestStreaks) ?? BestStreaks()
    soundEffects = try c.decodeIfPresent(Bool.self, forKey: .soundEffects) ?? true
    speedRoundNoTimer = try c.decodeIfPresent(Bool.self, forKey: .speedRoundNoTimer) ?? false
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
