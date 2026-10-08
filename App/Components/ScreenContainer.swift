import SwiftUI

/// Screen background plus a centred content column (max width 640), optionally scrolling.
struct ScreenContainer<Content: View>: View {
  @Environment(\.theme) private var theme
  private let scrolls: Bool
  private let maxWidth: CGFloat
  private let content: Content

  init(scrolls: Bool = true, maxWidth: CGFloat = 640, @ViewBuilder content: () -> Content) {
    self.scrolls = scrolls
    self.maxWidth = maxWidth
    self.content = content()
  }

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      if scrolls {
        ScrollView { column }
      } else {
        column
      }
    }
  }

  private var column: some View {
    content
      .frame(maxWidth: maxWidth, alignment: .leading)
      .padding(.horizontal, Spacing.lg)
      .padding(.vertical, Spacing.lg)
      .frame(maxWidth: .infinity)
  }
}

#Preview("Light") {
  ScreenContainer {
    Text("Screen content").font(Typography.body)
  }
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  ScreenContainer {
    Text("Screen content").font(Typography.body)
  }
  .preferredColorScheme(.dark)
}
