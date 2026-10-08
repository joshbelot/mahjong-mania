import SwiftUI

/// Placeholder root of the Game tab. Feature work replaces the body but keeps the title and
/// `settingsToolbar()` modifiers.
struct GameHomeView: View {
  var body: some View {
    ComingSoonView(title: "Game", symbol: "dice")
      .navigationTitle("Game")
      .settingsToolbar()
  }
}

#Preview("Light") {
  NavigationStack { GameHomeView() }.preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack { GameHomeView() }.preferredColorScheme(.dark)
}
