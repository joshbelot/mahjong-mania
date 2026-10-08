import SwiftUI

/// A surface card (radius 16, hairline border) with an optional small uppercase title.
struct SectionCard<Content: View>: View {
  @Environment(\.theme) private var theme
  private let title: String?
  private let content: Content

  init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      if let title {
        Text(title)
          .tinyStyle()
          .foregroundStyle(theme.textMuted)
          .accessibilityAddTraits(.isHeader)
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.lg)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
  }
}

#Preview("Light") {
  ScreenContainer {
    SectionCard("Players") {
      Text("Card body text").font(Typography.body)
    }
  }
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  ScreenContainer {
    SectionCard("Players") {
      Text("Card body text").font(Typography.body)
    }
  }
  .preferredColorScheme(.dark)
}
