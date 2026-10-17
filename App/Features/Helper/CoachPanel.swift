import MahjongCore
import SwiftUI

/// Pass suggestions (Charleston) or discard suggestions plus "Can I call it?" (Playing), gated per
/// SPEC §11.3: Peek shows them behind a button, Coach shows them automatically.
struct CoachPanel: View {
  @Environment(\.theme) private var theme
  @Environment(HelperStore.self) private var helper

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
      if helper.isCharlestonDone {
        header("Charleston done")
        hint("No more passes. Switch to Playing when the game starts.")
      } else if let locked = helper.charleston.locked {
        header(helper.currentStep?.isCourtesy == true ? "Pass up to 3" : "Pass these")
        lockedList(locked)
      } else if helper.rack.count < helper.fullRackSize {
        header(helper.currentStep?.isCourtesy == true ? "Pass up to 3" : "Pass these")
        hint("Add all 13 of your tiles (14 if you're East) to get a suggestion.")
      } else {
        header(helper.currentStep?.isCourtesy == true ? "Pass up to 3" : "Pass these")
        if gate.level == .coach {
          // Coach locks on its own as soon as the rack is full (see HelperView).
          hint("Working out what to pass\u{2026}")
        } else {
          Button {
            withAnimation(.smooth(duration: 0.2)) { helper.lockSuggestion(using: analyzer) }
          } label: {
            Label("Suggest a pass", systemImage: "lightbulb")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("helper.suggest")
        }
      }
    }
  }

  private func lockedList(_ locked: LockedPass) -> some View {
    let passed = locked.passed
    return VStack(alignment: .leading, spacing: Spacing.sm) {
      if locked.tiles.isEmpty {
        hint("There is nothing sensible to pass yet.")
      }
      ForEach(Array(locked.tiles.enumerated()), id: \.offset) { entry in
        let done = passed[entry.offset]
        let reason = locked.reasons.indices.contains(entry.offset) ? locked.reasons[entry.offset] : ""
        suggestionRow(
          tile: entry.element, text: done ? "\u{2713} Passed" : reason, dimmed: done,
          identifier: "pass.row.\(entry.offset)")
      }
      if !locked.focus.isEmpty {
        Text(focusSentence(locked.focus))
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("pass.focus")
      }
      Button("Suggest again") {
        withAnimation(.smooth(duration: 0.2)) { helper.lockSuggestion(using: analyzer) }
      }
      .font(Typography.small.weight(.semibold))
      .foregroundStyle(theme.primary)
      .frame(minHeight: 44)
      .accessibilityHint("Works out the 3 tiles again for your current tiles")
      .accessibilityIdentifier("pass.again")
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
        let suggestions = advisor.discards(
          analyzer, view: view, seen: seen, danger: danger, blanks: helper.blankPolicy)
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
      blankSwapAdvice
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

  /// Coach, holding a blank: tiles already thrown that a blank could be swapped for to get closer.
  @ViewBuilder
  private var blankSwapAdvice: some View {
    if gate.level == .coach, let policy = helper.blankPolicy, view.rack.contains(.blank) {
      let swaps = advisor.blankSwaps(analyzer, view: view, seen: seen, policy: policy)
      if !swaps.isEmpty {
        VStack(alignment: .leading, spacing: Spacing.sm) {
          Text("Your blank")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.textMuted)
          ForEach(Array(swaps.enumerated()), id: \.offset) { entry in
            HStack(spacing: Spacing.md) {
              TileView(tile: entry.element.tile, size: .small)
              Text(entry.element.text)
                .font(Typography.small)
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.element.text)
            .accessibilityIdentifier("blank.swap.\(entry.offset)")
          }
        }
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

  private func suggestionRow(
    tile: Tile, text: String, dimmed: Bool = false, identifier: String
  ) -> some View {
    HStack(spacing: Spacing.md) {
      TileView(tile: tile, size: .medium, state: dimmed ? .dim : .normal)
      Text(text)
        .font(Typography.small.weight(dimmed ? .semibold : .regular))
        .foregroundStyle(dimmed ? theme.primary : theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(tile.name). \(text)")
    .accessibilityIdentifier(identifier)
  }
}
