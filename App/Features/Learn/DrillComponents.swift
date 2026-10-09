import MahjongCore
import SwiftUI

/// Deal number (small, so a deal can be replayed) plus the streak counters.
struct DrillStatusBar: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let seed: UInt64
  let streak: Int
  let best: Int

  var body: some View {
    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs)) : AnyLayout(HStackLayout())
    layout {
      Text("Deal #\(seed)")
        .font(Typography.small.monospacedDigit())
        .foregroundStyle(theme.textMuted)
        .accessibilityIdentifier("drill.seed")
      if typeSize.isAccessibilitySize == false { Spacer(minLength: Spacing.sm) }
      Text("Streak \(streak) · Best \(best)")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.gold)
        .accessibilityIdentifier("drill.streak")
    }
  }
}

/// Try again (same deal) and Next deal.
struct DrillResultButtons: View {
  let onRetry: () -> Void
  let onNext: () -> Void

  var body: some View {
    VStack(spacing: Spacing.md) {
      Button("Next deal", action: onNext)
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("drill.next")
      Button("Try again", action: onRetry)
        .buttonStyle(PrimaryButton(.secondary, size: .large))
        .accessibilityHint("Replays the same deal")
        .accessibilityIdentifier("drill.tryagain")
    }
  }
}

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

/// The dealt hand as a wrapping rack of tiles (not interactive).
struct DrillHandView: View {
  @Environment(\.theme) private var theme
  let tiles: [Tile]

  var body: some View {
    FlowLayout(spacing: 4, lineSpacing: 6) {
      ForEach(Array(tiles.enumerated()), id: \.offset) { entry in
        TileView(tile: entry.element, size: .medium)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
  }
}
