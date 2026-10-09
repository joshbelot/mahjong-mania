import MahjongCore
import Observation

/// Remembers which coach tips were shown during this launch, so a tip never repeats within a session.
/// Each screen asks for its own tip by key and keeps it until it is dismissed.
@MainActor
@Observable
final class TipCenter {
  @ObservationIgnored private(set) var shownIDs: Set<String> = []
  @ObservationIgnored private var assigned: [String: CoachTip] = [:]
  @ObservationIgnored private var dismissed: Set<String> = []
  @ObservationIgnored private let sessionSeed: UInt64

  init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
    sessionSeed = seed
  }

  /// The tip for `screen`: the same one on every call until dismissed, a fresh unseen one on first use,
  /// nil once dismissed or when every tip has been shown.
  func tip(for screen: String) -> CoachTip? {
    if dismissed.contains(screen) { return nil }
    if let existing = assigned[screen] { return existing }
    let seed = sessionSeed &+ UInt64(shownIDs.count) &* 0x9E37_79B9_7F4A_7C15
    guard let tip = Tips.next(after: shownIDs, seed: seed) else { return nil }
    shownIDs.insert(tip.id)
    assigned[screen] = tip
    return tip
  }

  func dismiss(screen: String) {
    dismissed.insert(screen)
  }
}
