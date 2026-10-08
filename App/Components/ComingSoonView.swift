import SwiftUI

/// Title, SF Symbol and "Coming soon", used by tab roots until their feature lands.
struct ComingSoonView: View {
  @Environment(\.theme) private var theme
  let title: String
  let symbol: String

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      VStack(spacing: Spacing.md) {
        Image(systemName: symbol)
          .font(.system(size: 44))
          .foregroundStyle(theme.primary)
          .accessibilityHidden(true)
        Text(title)
          .titleStyle()
          .foregroundStyle(theme.text)
        Text("Coming soon")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
      }
      .padding(Spacing.xl)
    }
  }
}

#Preview("Light") {
  ComingSoonView(title: "Game", symbol: "dice").preferredColorScheme(.light)
}

#Preview("Dark") {
  ComingSoonView(title: "Game", symbol: "dice").preferredColorScheme(.dark)
}
