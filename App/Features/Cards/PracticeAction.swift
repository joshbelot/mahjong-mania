import SwiftUI

/// The four root tabs of `RootView`.
enum AppTab: Hashable, Sendable {
  case game, helper, cards, learn
}

/// Lets a deep screen switch the selected tab, e.g. "Practise this hand" opening the Helper.
/// `RootView` provides the real one; the default does nothing.
struct TabSwitcher {
  let select: @MainActor (AppTab) -> Void

  static var none: TabSwitcher { TabSwitcher(select: { _ in }) }
}

private struct TabSwitcherKey: EnvironmentKey {
  static var defaultValue: TabSwitcher { TabSwitcher.none }
}

extension EnvironmentValues {
  var tabSwitcher: TabSwitcher {
    get { self[TabSwitcherKey.self] }
    set { self[TabSwitcherKey.self] = newValue }
  }
}
