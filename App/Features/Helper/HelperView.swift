import SwiftUI

/// Placeholder root of the Helper tab. Feature work replaces the body but keeps the title and
/// `settingsToolbar()` modifiers.
struct HelperView: View {
  var body: some View {
    ComingSoonView(title: "Helper", symbol: "lightbulb")
      .navigationTitle("Helper")
      .settingsToolbar()
  }
}

#Preview("Light") {
  NavigationStack { HelperView() }.preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack { HelperView() }.preferredColorScheme(.dark)
}
