import MahjongCore
import SwiftUI

/// One "closest hand": line name, "N away", the compact pattern, points and badges. Tapping expands it
/// into tile mode with the missing tiles and a plain-English description (SPEC §11.7).
struct ResultCardView: View {
  @Environment(\.theme) private var theme

  let result: LineResult
  let index: Int
  let isPinned: Bool
  let isExpanded: Bool
  let showsMissingInline: Bool
  let onTap: () -> Void

  private var variant: PatternVariant? {
    let variants = result.line.variants
    let wanted = result.best.target.variantIndex
    if variants.indices.contains(wanted) { return variants[wanted] }
    return variants.first
  }

  private var missingTiles: [Tile] {
    result.best.missing.flatMap { Array(repeating: $0.tile, count: $0.count) }
  }

  private var awayLabel: String {
    result.best.possible ? HelperText.away(distance: result.best.distance) : "Not possible"
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        titleRow
        if let variant {
          if isExpanded {
            HandPatternView(
              variant: variant, line: result.line, evaluation: result.best, mode: .tiles)
            Text(
              Notation.describe(variant, shift: result.line.shift, concealed: result.line.concealed)
            )
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            HandPatternView(variant: variant, line: result.line, mode: .compact)
            metaRow
            if showsMissingInline && !missingTiles.isEmpty {
              MissingTilesRow(tiles: missingTiles)
            }
          }
        }
      }
      .padding(Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.md)
          .strokeBorder(isPinned ? theme.gold : theme.border, lineWidth: isPinned ? 2 : 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: Radius.md))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
    .accessibilityValue(isExpanded ? needText : "")
    .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to see the missing tiles")
    .accessibilityIdentifier("result.\(index)")
  }

  private var titleRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
      if isPinned {
        Image(systemName: "pin.fill")
          .font(Typography.small)
          .foregroundStyle(theme.gold)
          .accessibilityHidden(true)
      }
      Text(result.line.displayName)
        .font(Typography.body.weight(.semibold))
        .foregroundStyle(theme.text)
        .multilineTextAlignment(.leading)
      Spacer(minLength: Spacing.sm)
      Text(awayLabel)
        .font(Typography.small.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(result.best.possible ? theme.primary : theme.textMuted)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(
          result.best.possible ? theme.primarySoft : theme.surfaceAlt, in: Capsule())
    }
  }

  private var metaRow: some View {
    FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.xs) {
      Text("\(result.line.points) pts")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.textMuted)
      BadgeView(result.line.concealed ? .concealed : .exposed)
      if result.best.impossibleReason == .dead {
        BadgeView(.dead)
      }
      if result.best.possible && result.best.jokerlessPossible && !result.line.hasNoJokerGroups {
        BadgeView(.jokerless)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var needText: String {
    let names = missingTiles.map(\.name)
    return names.isEmpty ? "" : "Need " + names.joined(separator: ", ")
  }

  private var accessibilityText: String {
    var pieces = [result.line.displayName, awayLabel, "\(result.line.points) points"]
    pieces.append(result.line.concealed ? "Concealed hand" : "Exposed hand")
    if result.best.impossibleReason == .dead { pieces.append("Dead hand") }
    if result.best.possible && result.best.jokerlessPossible && !result.line.hasNoJokerGroups {
      pieces.append("Jokerless possible")
    }
    if isPinned { pieces.insert("Pinned", at: 0) }
    return pieces.joined(separator: ", ")
  }
}

/// "Need:" followed by small tiles for the tiles still missing.
struct MissingTilesRow: View {
  @Environment(\.theme) private var theme
  let tiles: [Tile]

  var body: some View {
    HStack(alignment: .top, spacing: Spacing.sm) {
      Text("Need:")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.textMuted)
        .frame(minHeight: TileSize.small.height)
      FlowLayout(spacing: 3, lineSpacing: 3) {
        ForEach(Array(tiles.enumerated()), id: \.offset) { entry in
          TileView(tile: entry.element, size: .small)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Need " + tiles.map(\.name).joined(separator: ", "))
  }
}

#Preview("Light") {
  ResultPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  ResultPreview().preferredColorScheme(.dark)
}

private struct ResultPreview: View {
  @Environment(\.theme) private var theme
  @State private var expanded: Int? = 1

  var body: some View {
    let analyzer = Analyzer(card: PracticeCard.card)
    let rack = ["2C", "2C", "2C", "6D", "6D", "6D", "0", "F", "F", "N", "E", "J", "9B"].compactMap {
      Tile(code: $0)
    }
    let results = analyzer.analyze(PlayerView(rack: rack))
    ScrollView {
      VStack(spacing: Spacing.sm) {
        ForEach(Array(results.prefix(4).enumerated()), id: \.element.line.id) { entry in
          ResultCardView(
            result: entry.element, index: entry.offset, isPinned: entry.offset == 0,
            isExpanded: expanded == entry.offset, showsMissingInline: true
          ) { expanded = expanded == entry.offset ? nil : entry.offset }
        }
      }
      .padding(Spacing.lg)
    }
    .background(theme.bg)
  }
}
