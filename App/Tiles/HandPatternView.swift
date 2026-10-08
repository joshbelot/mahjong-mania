import MahjongCore
import SwiftUI

enum PatternMode: Sendable {
  /// Coloured glyph text for lists, e.g. `FF 2026 2222 6666`.
  case compact
  /// Small tiles for the resolved best target, with a summary row below.
  case tiles
}

/// A card line drawn like the printed card (compact) or as tiles (tile mode). See SPEC §11.6.
struct HandPatternView: View {
  @Environment(\.theme) private var theme
  let variant: PatternVariant
  let line: CardLine?
  let evaluation: Evaluation?
  let showSuitLetters: Bool
  let mode: PatternMode
  let tileSize: TileSize

  init(
    variant: PatternVariant, line: CardLine? = nil, evaluation: Evaluation? = nil,
    showSuitLetters: Bool = false, mode: PatternMode = .compact, tileSize: TileSize = .small
  ) {
    self.variant = variant
    self.line = line
    self.evaluation = evaluation
    self.showSuitLetters = showSuitLetters
    self.mode = mode
    self.tileSize = tileSize
  }

  private var layout: PatternLayout {
    PatternLayout(variant: variant, showSuitLetters: showSuitLetters && mode == .compact)
  }

  var body: some View {
    switch mode {
    case .compact: compact
    case .tiles: tiles
    }
  }

  // MARK: Compact

  private var compact: some View {
    FlowLayout(spacing: Spacing.sm, lineSpacing: 2) {
      ForEach(Array(layout.items.enumerated()), id: \.offset) { entry in
        switch entry.element {
        case .body(let parts):
          Text(attributed(parts))
            .font(Typography.pattern)
        case .op(let text):
          Text(text)
            .font(Typography.pattern)
            .foregroundStyle(theme.textMuted)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Notation.describe(
        variant, shift: line?.shift ?? .none, concealed: line?.concealed ?? false))
  }

  private func attributed(_ parts: [PatternPart]) -> AttributedString {
    var result = AttributedString()
    for part in parts {
      let ink = color(for: part.ink)
      var glyphs = AttributedString(part.glyphs)
      glyphs.foregroundColor = ink
      result.append(glyphs)
      if let letter = part.suitLetter {
        var sub = AttributedString(letter)
        sub.foregroundColor = ink
        sub.font = Font.caption2.weight(.bold)
        sub.baselineOffset = -3
        result.append(sub)
      }
    }
    return result
  }

  private func color(for ink: PatternInk) -> Color {
    switch ink {
    case .variable(let variable):
      switch variable {
      case .x: return theme.varA
      case .y: return theme.varB
      case .z: return theme.varC
      }
    case .suit(let suit):
      switch suit {
      case .cracks: return theme.suitC
      case .bams: return theme.suitB
      case .dots: return theme.suitD
      }
    case .honor: return theme.text
    case .flower: return theme.flower
    }
  }

  // MARK: Tile mode

  private var tiles: some View {
    let slots = resolvedSlots
    return VStack(alignment: .leading, spacing: Spacing.sm) {
      FlowLayout(spacing: 8, lineSpacing: 6) {
        ForEach(Array(layout.items.enumerated()), id: \.offset) { entry in
          switch entry.element {
          case .body(let parts):
            HStack(spacing: 1) {
              ForEach(parts, id: \.groupIndex) { part in
                ForEach(Array((slots[part.groupIndex] ?? []).enumerated()), id: \.offset) { slot in
                  slotView(slot.element)
                }
              }
            }
          case .op(let text):
            Text(text)
              .font(Typography.pattern)
              .foregroundStyle(theme.textMuted)
              .accessibilityHidden(true)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      summaryRow
      needRow
    }
  }

  @ViewBuilder
  private func slotView(_ slot: PatternSlot) -> some View {
    switch slot.kind {
    case .natural:
      TileView(tile: slot.tile, size: tileSize)
    case .missing:
      TileView(tile: slot.tile, size: tileSize, state: .missing)
    case .joker:
      TileView(tile: .joker, size: tileSize)
        .overlay(alignment: .topTrailing) {
          Circle()
            .fill(theme.primary)
            .frame(width: 7, height: 7)
            .overlay(Circle().strokeBorder(theme.tileFace, lineWidth: 1))
            .offset(x: -2, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Joker standing in for \(slot.tile.name)")
    }
  }

  /// Slots per `PatternPart.groupIndex`.
  private var resolvedSlots: [Int: [PatternSlot]] {
    var map: [Int: [PatternSlot]] = [:]
    let variantGroupCount = variant.groups.count
    guard let evaluation, evaluation.target.groups.count == variantGroupCount else {
      for part in layout.parts {
        let tile = PatternLayout.exampleTile(for: part.spec.tile)
        map[part.groupIndex] = Array(
          repeating: PatternSlot(tile: tile, kind: .natural), count: part.spec.count)
      }
      return map
    }
    let groups = evaluation.target.groups
    let slots: [[PatternSlot]]
    if evaluation.impossibleReason == .concealed || evaluation.impossibleReason == .exposure {
      slots = groups.map { Array(repeating: PatternSlot(tile: $0.tile, kind: .missing), count: $0.count) }
    } else {
      var held = evaluation.usedRack
      held[.joker] = nil
      slots = PatternLayout.slots(
        groups: groups, missing: evaluation.missing, naturalsHeld: held,
        jokersUsed: evaluation.jokersUsed)
    }
    for (group, groupSlots) in zip(groups, slots) { map[group.groupIndex] = groupSlots }
    return map
  }

  @ViewBuilder
  private var summaryRow: some View {
    let text = summaryText
    if !text.isEmpty || evaluation?.impossibleReason == .dead {
      HStack(spacing: Spacing.sm) {
        if !text.isEmpty {
          Text(text)
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.textMuted)
        }
        if evaluation?.impossibleReason == .dead { BadgeView(.dead) }
        if evaluation?.jokerlessPossible == true && line?.hasNoJokerGroups == false {
          BadgeView(.jokerless)
        }
      }
    }
  }

  private var summaryText: String {
    var pieces: [String] = []
    if let evaluation {
      pieces.append(evaluation.distance == 0 ? "Mahjong" : "\(evaluation.distance) away")
    }
    if let line {
      pieces.append("\(line.points) pts")
      pieces.append(line.concealed ? "C" : "X")
    }
    return pieces.joined(separator: " \u{00B7} ")
  }

  @ViewBuilder
  private var needRow: some View {
    let needed = (evaluation?.missing ?? []).flatMap {
      Array(repeating: $0.tile, count: $0.count)
    }
    if !needed.isEmpty {
      HStack(alignment: .top, spacing: Spacing.sm) {
        Text("Need:")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
          .frame(minHeight: TileSize.small.height)
        FlowLayout(spacing: 3, lineSpacing: 3) {
          ForEach(Array(needed.enumerated()), id: \.offset) { entry in
            TileView(tile: entry.element, size: .small)
          }
        }
      }
    }
  }
}

// MARK: - Previews

private struct PatternPreview: View {
  @Environment(\.theme) private var theme
  let dark: Bool

  private let analyzer = Analyzer(card: PracticeCard.card)

  var body: some View {
    let rack = ["2C", "2C", "2C", "6D", "6D", "6D", "0", "F", "F", "N", "E", "J", "9B"].compactMap {
      Tile(code: $0)
    }
    let results = analyzer.analyze(PlayerView(rack: rack))
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        ForEach(PracticeCard.card.lines.prefix(6)) { line in
          if let variant = line.variants.first {
            HandPatternView(variant: variant, line: line, showSuitLetters: true)
          }
        }
        ForEach(results.prefix(3), id: \.line.id) { result in
          let index = min(result.best.target.variantIndex, result.line.variants.count - 1)
          HandPatternView(
            variant: result.line.variants[index], line: result.line, evaluation: result.best,
            mode: .tiles)
        }
      }
      .padding(Spacing.lg)
    }
    .background(theme.bg)
    .preferredColorScheme(dark ? .dark : .light)
  }
}

#Preview("Light") {
  PatternPreview(dark: false)
}

#Preview("Dark") {
  PatternPreview(dark: true)
}
