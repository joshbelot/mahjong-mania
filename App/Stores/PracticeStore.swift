import MahjongCore
import Observation
import SwiftUI

/// `practice.json` (SPEC §18.9): the Practice game's whole state. The file holds `version` next to the
/// fields of `PracticeProgress`.
struct PracticeDocument: VersionedDocument, Equatable {
  static let currentVersion = 1
  var version = PracticeDocument.currentVersion
  var progress = PracticeProgress()

  init(progress: PracticeProgress = PracticeProgress()) { self.progress = progress }

  private enum CodingKeys: String, CodingKey { case version }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    progress = try PracticeProgress(from: decoder)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(version, forKey: .version)
    try progress.encode(to: encoder)
  }
}

/// Today's date and hour in the user's calendar (or the one forced by `-UITestToday`).
struct PracticeClock: Sendable {
  var now: @Sendable () -> (day: LocalDay, hour: Int)

  static let system = PracticeClock {
    let date = Date()
    return (LocalDay(date, calendar: .current), Calendar.current.component(.hour, from: date))
  }

  /// A fixed day (UI tests, previews).
  static func fixed(_ day: LocalDay, hour: Int = 12) -> PracticeClock {
    PracticeClock { (day, hour) }
  }
}

@MainActor
@Observable
final class PracticeStore {
  private(set) var progress: PracticeProgress
  /// The tab to open on after onboarding (not saved).
  var startTab: AppTab?
  /// What happened to the streak when the app opened today (a freeze used, or a break), until it is shown.
  var pendingStreakEvents: [StreakEvent] = []
  @ObservationIgnored let clock: PracticeClock
  @ObservationIgnored private let persister: Persister<PracticeDocument>
  /// True when `practice.json` existed at launch.
  @ObservationIgnored let loadedFromFile: Bool

  init(directory: URL, persistDelay: Duration = .milliseconds(300), clock: PracticeClock = .system) {
    let file = JSONFileStore<PracticeDocument>(directory: directory, name: "practice")
    let loaded = file.load()
    loadedFromFile = loaded != nil
    progress = loaded?.progress ?? PracticeProgress()
    self.clock = clock
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in self.map { PracticeDocument(progress: $0.progress) } }
  }

  var today: LocalDay { clock.now().day }
  var hour: Int { clock.now().hour }

  func update(_ change: (inout PracticeProgress) -> Void) {
    var copy = progress
    change(&copy)
    guard copy != progress else { return }
    progress = copy
    persister.changed()
  }

  /// Applies a finished play and saves it right away (a lesson is worth not losing).
  @discardableResult
  func apply(_ result: PlayResult) -> PlayOutcome? {
    var copy = progress
    guard let outcome = copy.apply(result) else { return nil }
    progress = copy
    persister.changed()
    persister.flush()
    return outcome
  }

  func applyPlacement(_ placement: Placement) {
    update { $0.applyPlacement(placement) }
    startTab = placement == .regular ? .game : .practice
  }

  /// Closes the days gone by (freezes, a broken streak). Call when the app opens or returns to the front.
  func openDay() {
    var events: [StreakEvent] = []
    update { events = $0.openDay(today) }
    pendingStreakEvents += events
  }

  func clearPendingStreakEvents() { pendingStreakEvents = [] }

  /// First launch of 1.2: the drills' best streaks move here from Settings.
  func importBestStreaks(_ streaks: BestStreaks) {
    guard !loadedFromFile, streaks.pickAHand > 0 || streaks.charleston > 0 else { return }
    update {
      $0.freePlay.pickStreakBest = max($0.freePlay.pickStreakBest, streaks.pickAHand)
      $0.freePlay.charlestonStreakBest = max($0.freePlay.charlestonStreakBest, streaks.charleston)
    }
  }

  func setBestStreak(pickAHand: Int? = nil, charleston: Int? = nil) {
    update {
      if let pickAHand { $0.freePlay.pickStreakBest = max($0.freePlay.pickStreakBest, pickAHand) }
      if let charleston { $0.freePlay.charlestonStreakBest = max($0.freePlay.charlestonStreakBest, charleston) }
    }
  }

  /// Streak set-up from `-UITestDayLog`, `-UITestFreezes` and `-UITestDailyGoal` (UI tests only).
  func applyLaunchOptions() {
    let days = LaunchOptions.dayLog()
    let freezes = LaunchOptions.freezes()
    let goal = LaunchOptions.dailyGoal()
    guard !days.isEmpty || freezes != nil || goal != nil else { return }
    update {
      if let goal {
        $0.dailyGoal = goal
        $0.goalChosen = true
      }
      for day in days { $0.recordDay(day) }
      if let freezes { $0.streak.freezes = freezes }
    }
  }

  func flush() { persister.flush() }

  /// Settings → Reset practice progress (and Reset all data).
  func reset() {
    persister.removeFile()
    progress = PracticeProgress()
    startTab = nil
    pendingStreakEvents = []
  }

  var writeCount: Int { persister.writeCount }
}
