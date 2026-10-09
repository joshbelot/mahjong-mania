import MahjongCore
import SwiftUI

/// A pattern variant drawn as tiles with the suits of one concrete `Target` (tile mode without an
/// evaluation). With no target, suits fall back to the example colours A = Cracks, B = Bams, C = Dots.
struct ResolvedPatternView: View {
  @Environment(\.theme) private var theme
  let variant: PatternVariant
  let target: Target?
  let size: TileSize
  let accessibilityText: String

  init(variant: PatternVariant, target: Target?, size: TileSize = .small, accessibilityText: String = "") {
    self.variant = variant
    self.target = target
    self.size = size
    self.accessibilityText = accessibilityText
  }

  private var layout: PatternLayout { PatternLayout(variant: variant) }

  var body: some View {
    FlowLayout(spacing: 8, lineSpacing: 6) {
      ForEach(Array(layout.items.enumerated()), id: \.offset) { entry in
        switch entry.element {
        case .body(let parts):
          HStack(spacing: 1) {
            ForEach(parts, id: \.groupIndex) { part in
              ForEach(0..<part.spec.count, id: \.self) { _ in
                TileView(tile: tile(for: part), size: size)
              }
            }
          }
        case .op(let text):
          Text(text)
            .font(Typography.pattern)
            .foregroundStyle(theme.textMuted)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText.isEmpty ? variant.source : accessibilityText)
  }

  private func tile(for part: PatternPart) -> Tile {
    if let target, let group = target.groups.first(where: { $0.groupIndex == part.groupIndex }) {
      return group.tile
    }
    return PatternLayout.exampleTile(for: part.spec.tile)
  }
}

/// A small rounded label such as "Built-in".
struct PillLabel: View {
  @Environment(\.theme) private var theme
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .tinyStyle()
      .foregroundStyle(theme.primary)
      .padding(.horizontal, Spacing.sm)
      .padding(.vertical, 3)
      .background(theme.primarySoft, in: Capsule())
  }
}

#Preview("Light") {
  ResolvedPatternView(
    variant: PracticeCard.card.lines[0].variants[0], target: Engine.expand(PracticeCard.card.lines[0]).first,
    size: .medium
  )
  .padding()
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  ResolvedPatternView(
    variant: PracticeCard.card.lines[0].variants[0], target: Engine.expand(PracticeCard.card.lines[0]).first,
    size: .medium
  )
  .padding()
  .preferredColorScheme(.dark)
}
