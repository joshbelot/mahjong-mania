import SwiftUI

/// A row of views that becomes a column at accessibility text sizes, where a row would squeeze
/// names, scores and labels until they truncate or break mid-word.
struct AdaptiveStack<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  private let horizontalAlignment: HorizontalAlignment
  private let verticalAlignment: VerticalAlignment
  private let spacing: CGFloat?
  private let content: Content

  init(
    horizontalAlignment: HorizontalAlignment = .leading,
    verticalAlignment: VerticalAlignment = .center,
    spacing: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.horizontalAlignment = horizontalAlignment
    self.verticalAlignment = verticalAlignment
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: horizontalAlignment, spacing: spacing) { content }
    } else {
      HStack(alignment: verticalAlignment, spacing: spacing) { content }
    }
  }
}

/// Shows the icon next to the title, but only the title at accessibility text sizes, so a button
/// label wraps by word instead of squeezing its text next to an icon.
struct AdaptiveLabelStyle: LabelStyle {
  @Environment(\.dynamicTypeSize) private var typeSize

  func makeBody(configuration: Configuration) -> some View {
    if typeSize.isAccessibilitySize {
      configuration.title
    } else {
      Label(configuration)
    }
  }
}
