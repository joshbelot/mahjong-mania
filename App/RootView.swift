import SwiftUI

/// The four tabs. Each tab's root view lives in its feature folder and applies its own title and
/// `settingsToolbar()`.
struct RootView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings

  var body: some View {
    TabView {
      NavigationStack { GameHomeView() }
        .tabItem { Label("Game", systemImage: "dice") }
        .accessibilityIdentifier("tab.game")
      if HelperGate(settings.settings.assistLevel).showsHelperTab {
        NavigationStack { HelperView() }
          .tabItem { Label("Helper", systemImage: "lightbulb") }
          .accessibilityIdentifier("tab.helper")
      }
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
  RootView()
    .environment(AppStores.inMemory().settings)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .environment(AppStores.inMemory().settings)
    .preferredColorScheme(.dark)
}
