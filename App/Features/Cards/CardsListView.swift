import SwiftUI

/// Placeholder root of the Cards tab. Feature work replaces the body but keeps the title and
/// `settingsToolbar()` modifiers.
struct CardsListView: View {
  var body: some View {
    ComingSoonView(title: "Cards", symbol: "rectangle.stack")
      .navigationTitle("Cards")
      .settingsToolbar()
  }
}

#Preview("Light") {
  NavigationStack { CardsListView() }.preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack { CardsListView() }.preferredColorScheme(.dark)
}
