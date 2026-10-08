import SwiftUI

/// Placeholder root of the Learn tab. Feature work replaces the body but keeps the title and
/// `settingsToolbar()` modifiers.
struct LearnHomeView: View {
  var body: some View {
    ComingSoonView(title: "Learn", symbol: "graduationcap")
      .navigationTitle("Learn")
      .settingsToolbar()
  }
}

#Preview("Light") {
  NavigationStack { LearnHomeView() }.preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack { LearnHomeView() }.preferredColorScheme(.dark)
}
