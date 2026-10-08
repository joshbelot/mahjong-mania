import SwiftUI

/// A selectable pill used for players and quick point values.
/// With a `tint` (e.g. a player colour) the selected state uses a tinted ring instead of a solid fill.
struct ChipView: View {
  @Environment(\.theme) private var theme
  private let title: String
  private let isSelected: Bool
  private let tint: Color?
  private let action: () -> Void

  init(_ title: String, isSelected: Bool, tint: Color? = nil, action: @escaping () -> Void) {
    self.title = title
    self.isSelected = isSelected
    self.tint = tint
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: Spacing.xs) {
        if let tint {
          Circle().fill(tint).frame(width: 10, height: 10)
        }
        Text(title)
          .font(Typography.body.weight(.medium))
          .foregroundStyle(solidSelected ? theme.onPrimary : theme.text)
      }
      .padding(.horizontal, Spacing.lg)
      .frame(minHeight: 44)
      .background(fill, in: Capsule())
      .overlay(Capsule().strokeBorder(stroke, lineWidth: isSelected ? 2 : 1))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var solidSelected: Bool { isSelected && tint == nil }

  private var fill: Color {
    if solidSelected { return theme.primary }
    if isSelected { return theme.surfaceAlt }
    return theme.surface
  }

  private var stroke: Color {
    if isSelected { return tint ?? theme.primary }
    return theme.border
  }
}

private struct ChipPreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      HStack {
        ChipView("25", isSelected: true) {}
        ChipView("30", isSelected: false) {}
        ChipView("35", isSelected: false) {}
      }
      HStack {
        ChipView("Bea", isSelected: true, tint: PlayerPalette.color(at: 1)) {}
        ChipView("Cy", isSelected: false, tint: PlayerPalette.color(at: 2)) {}
      }
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  ChipPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  ChipPreview().preferredColorScheme(.dark)
}
