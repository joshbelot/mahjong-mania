import MahjongCore
import SwiftUI

/// "Can I call it?": pick the tile that was just discarded and see whether to call it (SPEC §11.7).
struct CallCheckSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss

  let analyzer: Analyzer
  let view: PlayerView
  /// Copies of each tile already accounted for (rack, exposures, seen tiles).
  let usage: TileCounts
  let gate: HelperGate

  @State private var tile: Tile?
  @State private var verdicts: [CallVerdict] = []

  private static let maxRows = 5

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          Text("Which tile was discarded?")
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("call.prompt")
          if let tile {
            answer(for: tile)
          }
          TileKeyboardView(
            onAdd: { picked in
              // A discarded joker cannot be called.
              guard picked != .joker else { return }
              tile = picked
              verdicts = analyzer.checkCall(view, tile: picked)
            }, usage: usage)
        }
        .padding(Spacing.lg)
      }
      .background(theme.bg)
      .navigationTitle("Can I call it?")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("call.done")
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private func answer(for tile: Tile) -> some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      HStack(spacing: Spacing.md) {
        TileView(tile: tile, size: .large)
        Text(tile.name)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
      }
      if verdicts.isEmpty {
        verdictRow(
          title: HelperText.letItGo, detail: nil, tint: theme.textMuted, background: theme.surfaceAlt,
          identifier: "call.verdict.none")
      } else {
        ForEach(Array(verdicts.prefix(Self.maxRows).enumerated()), id: \.offset) { entry in
          verdictRow(for: entry.element, tile: tile, index: entry.offset)
        }
      }
    }
  }

  private func verdictRow(for verdict: CallVerdict, tile: Tile, index: Int) -> some View {
    let line: CardLine
    let isMahjong: Bool
    switch verdict {
    case .mahjong(let found):
      line = found
      isMahjong = true
    case .expose(let found, _, _):
      line = found
      isMahjong = false
    }
    var detail = "\(line.displayName) \u{00B7} \(line.points) pts"
    if gate.explainsCalls {
      detail += "\n" + HelperText.explanation(for: verdict, tile: tile)
    }
    return verdictRow(
      title: HelperText.headline(for: verdict), detail: detail,
      tint: isMahjong ? theme.success : theme.primary,
      background: isMahjong ? theme.primarySoft : theme.surface,
      identifier: "call.verdict.\(index)")
  }

  private func verdictRow(
    title: String, detail: String?, tint: Color, background: Color, identifier: String
  ) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text(title)
        .font(Typography.body.weight(.semibold))
        .foregroundStyle(tint)
      if let detail {
        Text(detail)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.md)
    .background(background, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(detail.map { "\(title). \($0)" } ?? title)
    .accessibilityIdentifier(identifier)
  }
}
