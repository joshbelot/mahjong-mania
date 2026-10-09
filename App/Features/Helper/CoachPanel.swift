import MahjongCore
import SwiftUI

/// Pass suggestions (Charleston) or discard suggestions plus "Can I call it?" (Playing), gated per
/// SPEC §11.3: Peek shows them behind a button, Coach shows them automatically.
struct CoachPanel: View {
  @Environment(\.theme) private var theme

  let mode: HelperMode
  let analyzer: Analyzer
  let view: PlayerView
  let seen: TileCounts
  let danger: [Tile: Double]
  let gate: HelperGate
  let advisor: HelperAdvisor
  @Binding var revealed: Bool
  let onCallCheck: () -> Void

  private var exposedTiles: Int { view.exposures.reduce(0) { $0 + $1.tiles.count } }

  var body: some View {
    switch mode {
    case .charleston: passes
    case .playing: playing
    case .scout: EmptyView()
    }
  }

  // MARK: Charleston

  private var passes: some View {
    SectionCard {
      header("Pass these")
      if view.rack.count < 3 {
        hint("Add at least three tiles to see which to pass.")
      } else if gate.showsSuggestions(revealed: revealed) {
        let advice = advisor.passes(analyzer, view: view)
        if advice.passes.isEmpty {
          hint("There is nothing sensible to pass yet.")
        } else {
          VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(advice.passes.enumerated()), id: \.offset) { entry in
              suggestionRow(
                tile: entry.element.tile, text: entry.element.reason,
                identifier: "pass.row.\(entry.offset)")
            }
          }
        }
        if !advice.focus.isEmpty {
          Text(focusSentence(advice.focus.map(\.section)))
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("pass.focus")
        }
      } else {
        revealButton("Suggest a pass")
      }
    }
  }

  private func focusSentence(_ sections: [String]) -> AttributedString {
    var text = AttributedString()
    for segment in HelperText.focusSegments(sections) {
      var piece = AttributedString(segment.text)
      if segment.bold { piece.inlinePresentationIntent = .stronglyEmphasized }
      text.append(piece)
    }
    return text
  }

  // MARK: Playing

  private var playing: some View {
    SectionCard {
      header("Discard")
      if view.rack.count + exposedTiles < HelperRules.handSize {
        hint("Discard suggestions need your full 14 tiles: 13 plus the one you just drew.")
      } else if gate.showsSuggestions(revealed: revealed) {
        let suggestions = advisor.discards(analyzer, view: view, seen: seen, danger: danger)
        if suggestions.isEmpty {
          hint("There is nothing sensible to discard yet.")
        } else {
          VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { entry in
              suggestionRow(
                tile: entry.element.tile, text: entry.element.reason,
                identifier: "discard.row.\(entry.offset)")
            }
          }
        }
      } else {
        revealButton("Suggest a discard")
      }
      if gate.offersCallCheck {
        Button(action: onCallCheck) {
          Label("Can I call it?", systemImage: "hand.raised")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButton(.secondary, size: .large))
        .accessibilityHint("Pick the tile someone just discarded")
        .accessibilityIdentifier("helper.call")
      }
    }
  }

  // MARK: Pieces

  private func header(_ title: String) -> some View {
    Text(title)
      .font(Typography.h2)
      .foregroundStyle(theme.text)
      .accessibilityAddTraits(.isHeader)
  }

  private func hint(_ text: String) -> some View {
    Text(text)
      .font(Typography.small)
      .foregroundStyle(theme.textMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func revealButton(_ title: String) -> some View {
    Button {
      withAnimation(.smooth(duration: 0.2)) { revealed = true }
    } label: {
      Label(title, systemImage: "lightbulb")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(PrimaryButton(.primary, size: .large))
    .accessibilityIdentifier("helper.suggest")
  }

  private func suggestionRow(tile: Tile, text: String, identifier: String) -> some View {
    HStack(spacing: Spacing.md) {
      TileView(tile: tile, size: .medium)
      Text(text)
        .font(Typography.small)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(tile.name). \(text)")
    .accessibilityIdentifier(identifier)
  }
}
