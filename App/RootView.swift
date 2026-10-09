import SwiftUI

/// The four tabs. Each tab's root view lives in its feature folder and applies its own title and
/// `settingsToolbar()`.
struct RootView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @State private var selectedTab: AppTab = .game
  @State private var cardsPath: [CardsRoute] = []

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack { GameHomeView() }
        .tabItem { Label("Game", systemImage: "dice") }
        .accessibilityIdentifier("tab.game")
        .tag(AppTab.game)
      if HelperGate(settings.settings.assistLevel).showsHelperTab {
        NavigationStack { HelperView() }
          .tabItem { Label("Helper", systemImage: "lightbulb") }
          .accessibilityIdentifier("tab.helper")
          .tag(AppTab.helper)
      }
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
    .onChange(of: settings.settings.assistLevel) {
      if selectedTab == .helper && !HelperGate(settings.settings.assistLevel).showsHelperTab {
        selectedTab = .game
      }
    }
  }
}

#Preview("Light") {
  RootView()
    .environment(AppStores.inMemory().settings)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .environment(AppStores.inMemory().settings)
    .preferredColorScheme(.dark)
}
