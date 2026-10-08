import SwiftUI

/// The four tabs. Each tab's root view lives in its feature folder and applies its own title and
/// `settingsToolbar()`.
struct RootView: View {
  @Environment(\.theme) private var theme

  var body: some View {
    TabView {
      NavigationStack { GameHomeView() }
        .tabItem { Label("Game", systemImage: "dice") }
        .accessibilityIdentifier("tab.game")
      NavigationStack { HelperView() }
        .tabItem { Label("Helper", systemImage: "lightbulb") }
        .accessibilityIdentifier("tab.helper")
      NavigationStack { CardsListView() }
        .tabItem { Label("Cards", systemImage: "rectangle.stack") }
        .accessibilityIdentifier("tab.cards")
      NavigationStack { LearnHomeView() }
        .tabItem { Label("Learn", systemImage: "graduationcap") }
        .accessibilityIdentifier("tab.learn")
    }
    .tint(theme.primary)
  }
}

#Preview("Light") {
  RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView().preferredColorScheme(.dark)
}
