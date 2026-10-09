import SwiftUI

/// The four tabs. Each tab's root view lives in its feature folder and applies its own title and
/// `settingsToolbar()`.
struct RootView: View {
  @Environment(\.theme) private var theme
  @State private var selectedTab: AppTab = .game
  @State private var cardsPath: [CardsRoute] = []

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack { GameHomeView() }
        .tabItem { Label("Game", systemImage: "dice") }
        .accessibilityIdentifier("tab.game")
        .tag(AppTab.game)
      NavigationStack { HelperView() }
        .tabItem { Label("Helper", systemImage: "lightbulb") }
        .accessibilityIdentifier("tab.helper")
        .tag(AppTab.helper)
      NavigationStack(path: $cardsPath) { CardsListView() }
        .tabItem { Label("Cards", systemImage: "rectangle.stack") }
        .accessibilityIdentifier("tab.cards")
        .tag(AppTab.cards)
      NavigationStack { LearnHomeView() }
        .tabItem { Label("Learn", systemImage: "graduationcap") }
        .accessibilityIdentifier("tab.learn")
        .tag(AppTab.learn)
    }
    .tint(theme.primary)
    .environment(\.tabSwitcher, TabSwitcher { selectedTab = $0 })
    .environment(\.cardsNavigator, CardsNavigator { cardsPath.append($0) })
  }
}

#Preview("Light") {
  RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView().preferredColorScheme(.dark)
}
