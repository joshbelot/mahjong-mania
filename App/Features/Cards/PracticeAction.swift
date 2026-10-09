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

/// Pushes a screen onto the Cards tab's navigation stack from code (after creating, duplicating or
/// importing a card). `RootView` owns the stack's path and provides the real one.
struct CardsNavigator {
  let push: @MainActor (CardsRoute) -> Void

  static var none: CardsNavigator { CardsNavigator(push: { _ in }) }
}

private struct CardsNavigatorKey: EnvironmentKey {
  static var defaultValue: CardsNavigator { CardsNavigator.none }
}

extension EnvironmentValues {
  var cardsNavigator: CardsNavigator {
    get { self[CardsNavigatorKey.self] }
    set { self[CardsNavigatorKey.self] = newValue }
  }
}
