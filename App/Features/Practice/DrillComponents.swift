import MahjongCore
import SwiftUI

/// A line's name, points and X/C badge above its compact pattern.
struct DrillLineSummary: View {
  @Environment(\.theme) private var theme
  let line: CardLine
  var detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
        Text(line.displayName)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.leading)
        Spacer(minLength: Spacing.sm)
        Text("\(line.points) pts")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        BadgeView(line.concealed ? .concealed : .exposed)
      }
      if let detail {
        Text(detail)
          .font(Typography.small.weight(.medium))
          .foregroundStyle(theme.primary)
      }
      if let variant = line.variants.first {
        HandPatternView(variant: variant, line: line, mode: .compact)
      }
    }
  }
}
