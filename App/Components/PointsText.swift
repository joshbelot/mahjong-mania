import SwiftUI

/// Signed points: green with "+" when positive, red with "−" (U+2212) when negative, muted at zero.
struct PointsText: View {
  @Environment(\.theme) private var theme
  let points: Int
  var showUnit = false

  init(_ points: Int, showUnit: Bool = false) {
    self.points = points
    self.showUnit = showUnit
  }

  static func format(_ points: Int) -> String {
    if points > 0 { return "+\(points)" }
    if points < 0 { return "\u{2212}\(-points)" }
    return "0"
  }

  var body: some View {
    Text(Self.format(points) + (showUnit ? " pts" : ""))
      .font(Typography.body.weight(.semibold))
      .monospacedDigit()
      .foregroundStyle(color)
      .accessibilityLabel(spoken)
  }

  private var color: Color {
    if points > 0 { return theme.success }
    if points < 0 { return theme.danger }
    return theme.textMuted
  }

  private var spoken: String {
    if points > 0 { return "plus \(points) points" }
    if points < 0 { return "minus \(-points) points" }
    return "0 points"
  }
}

private struct PointsPreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    HStack(spacing: Spacing.lg) {
      PointsText(75)
      PointsText(-25)
      PointsText(0)
      PointsText(50, showUnit: true)
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  PointsPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  PointsPreview().preferredColorScheme(.dark)
}
