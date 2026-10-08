import MahjongCore
import SwiftUI

/// Drill: look at 13 dealt tiles, tap the card line you would aim for, then see the engine's top three.
struct PickAHandDrillView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(CardsStore.self) private var cards

  @State private var drill = PickAHandDrill(seed: DrillSeed.initial())
  @State private var outcome: PickAHandDrill.Outcome?
  @State private var streak = 0
  /// Only the first answer to a deal moves the streak, so replaying a deal cannot farm it.
  @State private var countsForStreak = true

  private var analyzer: Analyzer? {
    cards.analyzer(for: settings.settings.activeCardID) ?? cards.analyzer(for: PracticeCard.card.id)
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        DrillStatusBar(
          seed: drill.seed, streak: streak, best: settings.settings.bestStreaks.pickAHand)
        DrillHandView(tiles: drill.hand)
        if let outcome {
          revealed(outcome)
        } else {
          picking
        }
      }
    }
    .navigationTitle("Pick-a-Hand")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Picking

  @ViewBuilder
  private var picking: some View {
    Text("Which line would you aim for? Tap one.")
      .font(Typography.h2)
      .foregroundStyle(theme.text)
      .accessibilityAddTraits(.isHeader)
    if let analyzer {
      VStack(spacing: Spacing.sm) {
        ForEach(Array(analyzer.card.lines.enumerated()), id: \.element.id) { entry in
          Button {
            pick(entry.element)
          } label: {
            DrillLineSummary(line: entry.element)
              .padding(Spacing.md)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
              .overlay(
                RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1)
              )
              .contentShape(RoundedRectangle(cornerRadius: Radius.md))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(entry.element.displayName), \(entry.element.points) points")
          .accessibilityHint("I'd go for this")
          .accessibilityIdentifier("pick.line.\(entry.offset)")
        }
      }
    } else {
      Text("This card could not be loaded.")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
    }
  }

  // MARK: Revealed

  @ViewBuilder
  private func revealed(_ outcome: PickAHandDrill.Outcome) -> some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: outcome.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.title2)
        .foregroundStyle(outcome.isCorrect ? theme.success : theme.danger)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(outcome.isCorrect ? "Good pick!" : "Not in the top three")
          .font(Typography.h2)
          .foregroundStyle(theme.text)
        Text("You chose \(outcome.picked.name), \(awayText(outcome.picked.distance)).")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("drill.result")

    SectionCard("Closest lines") {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        ForEach(Array(outcome.top.enumerated()), id: \.element.id) { entry in
          DrillLineSummary(
            line: entry.element.line,
            detail: "\(entry.offset + 1). \(awayText(entry.element.distance))"
              + (entry.element.id == outcome.picked.id ? " · your pick" : ""))
          if entry.offset < outcome.top.count - 1 { Divider() }
        }
      }
    }
    SectionCard("Why") {
      Text(outcome.explanation)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("drill.explanation")
    }
    DrillResultButtons(onRetry: tryAgain, onNext: nextDeal)
  }

  // MARK: Actions

  private func pick(_ line: CardLine) {
    guard outcome == nil, let analyzer,
      let result = drill.outcome(pickedLineID: line.id, analyzer: analyzer)
    else { return }
    withAnimation(.smooth(duration: 0.2)) { outcome = result }
    if countsForStreak {
      streak = PickAHandDrill.updatedStreak(streak, correct: result.isCorrect)
      settings.setBestStreak(pickAHand: streak)
      countsForStreak = false
    }
  }

  /// Same deal, same seed; the streak is not touched again.
  private func tryAgain() {
    withAnimation(.smooth(duration: 0.2)) { outcome = nil }
  }

  private func nextDeal() {
    drill = PickAHandDrill(seed: DrillSeed.random())
    countsForStreak = true
    withAnimation(.smooth(duration: 0.2)) { outcome = nil }
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { PickAHandDrillView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { PickAHandDrillView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .preferredColorScheme(.dark)
}
