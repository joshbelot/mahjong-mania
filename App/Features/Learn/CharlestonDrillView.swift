import MahjongCore
import SwiftUI

/// A horizontal wobble that returns to rest when `shakes` is a whole number.
private struct ShakeEffect: GeometryEffect {
  var shakes: CGFloat

  var animatableData: CGFloat {
    get { shakes }
    set { shakes = newValue }
  }

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 6), y: 0))
  }
}

/// Drill: pick 3 of 13 dealt tiles to pass, then compare with the engine's suggestion.
struct CharlestonDrillView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(CardsStore.self) private var cards

  @State private var drill = CharlestonDrill(seed: DrillSeed.initial())
  @State private var selection: [Int] = []
  @State private var outcome: CharlestonDrill.Outcome?
  @State private var message: String?
  @State private var shakes: [Int: Int] = [:]
  @State private var warnings = 0
  @State private var streak = 0
  @State private var countsForStreak = true

  private var analyzer: Analyzer? {
    cards.analyzer(for: settings.settings.activeCardID) ?? cards.analyzer(for: PracticeCard.card.id)
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        DrillStatusBar(
          seed: drill.seed, streak: streak, best: settings.settings.bestStreaks.charleston)
        if let outcome {
          revealed(outcome)
        } else {
          picking
        }
      }
    }
    .navigationTitle("Charleston Pass")
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(.warning, trigger: warnings)
  }

  // MARK: Picking

  @ViewBuilder
  private var picking: some View {
    Text("Choose 3 tiles to pass.")
      .font(Typography.h2)
      .foregroundStyle(theme.text)
      .accessibilityAddTraits(.isHeader)
    Text("Tap a tile to select it, tap again to put it back. Jokers can't be passed.")
      .font(Typography.small)
      .foregroundStyle(theme.textMuted)
      .fixedSize(horizontal: false, vertical: true)
    handView
    HStack(spacing: Spacing.sm) {
      Text("Selected \(selection.count) of \(CharlestonDrill.passCount)")
        .font(Typography.small.weight(.semibold).monospacedDigit())
        .foregroundStyle(theme.text)
        .accessibilityIdentifier("charleston.count")
    }
    if let message {
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.danger)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("charleston.message")
    }
    Button("Submit", action: submit)
      .buttonStyle(PrimaryButton(.primary, size: .large))
      .disabled(selection.count != CharlestonDrill.passCount)
      .accessibilityIdentifier("charleston.submit")
  }

  private var handView: some View {
    FlowLayout(spacing: 4, lineSpacing: 10) {
      ForEach(Array(drill.hand.enumerated()), id: \.offset) { entry in
        Button {
          tap(entry.offset)
        } label: {
          TileView(
            tile: entry.element, size: .medium,
            state: selection.contains(entry.offset) ? .selected : .normal
          )
          .frame(minWidth: 44, minHeight: 58)
          .modifier(ShakeEffect(shakes: CGFloat(shakes[entry.offset, default: 0])))
          .animation(.linear(duration: 0.4), value: shakes[entry.offset, default: 0])
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.element.name)
        .accessibilityAddTraits(selection.contains(entry.offset) ? .isSelected : [])
        .accessibilityIdentifier("charleston.tile.\(entry.offset)")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
  }

  // MARK: Revealed

  @ViewBuilder
  private func revealed(_ outcome: CharlestonDrill.Outcome) -> some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: outcome.isPerfect ? "checkmark.circle.fill" : "circle.lefthalf.filled")
        .font(.title2)
        .foregroundStyle(outcome.isPerfect ? theme.success : theme.warning)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("Score \(outcome.score) of \(CharlestonDrill.passCount)")
          .font(Typography.h2)
          .foregroundStyle(theme.text)
        Text(outcome.isPerfect ? "Streak continues." : "Streak reset.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("drill.result")

    DrillHandView(tiles: drill.hand)
    passSet(title: "You passed", picks: outcome.chosen)
    passSet(title: "The engine would pass", picks: outcome.engine)
    SectionCard("Why") {
      Text(outcome.explanation)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("drill.explanation")
    }
    DrillResultButtons(onRetry: tryAgain, onNext: nextDeal)
  }

  private func passSet(title: String, picks: [CharlestonDrill.Pick]) -> some View {
    SectionCard(title) {
      VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(Array(picks.enumerated()), id: \.offset) { entry in
          HStack(alignment: .center, spacing: Spacing.md) {
            TileView(tile: entry.element.tile, size: .small)
            Text(entry.element.reason)
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  // MARK: Actions

  private func tap(_ index: Int) {
    guard drill.hand.indices.contains(index) else { return }
    let tile = drill.hand[index]
    if !CharlestonDrill.canSelect(tile) {
      shakes[index, default: 0] += 1
      warnings += 1
      message = "Jokers can't be passed"
      return
    }
    if let position = selection.firstIndex(of: index) {
      selection.remove(at: position)
      message = nil
    } else if selection.count < CharlestonDrill.passCount {
      selection.append(index)
      message = nil
    } else {
      warnings += 1
      message = "That's 3 already. Tap a selected tile to put it back."
    }
  }

  private func submit() {
    guard outcome == nil, let analyzer,
      let result = drill.evaluate(selection: selection, analyzer: analyzer)
    else { return }
    withAnimation(.smooth(duration: 0.2)) { outcome = result }
    if countsForStreak {
      streak = CharlestonDrill.updatedStreak(streak, score: result.score)
      settings.setBestStreak(charleston: streak)
      countsForStreak = false
    }
  }

  /// Same deal, same seed; the streak is not touched again.
  private func tryAgain() {
    selection = []
    message = nil
    withAnimation(.smooth(duration: 0.2)) { outcome = nil }
  }

  private func nextDeal() {
    drill = CharlestonDrill(seed: DrillSeed.random())
    selection = []
    message = nil
    shakes = [:]
    countsForStreak = true
    withAnimation(.smooth(duration: 0.2)) { outcome = nil }
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { CharlestonDrillView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { CharlestonDrillView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .preferredColorScheme(.dark)
}
