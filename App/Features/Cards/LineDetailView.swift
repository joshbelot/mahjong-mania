import MahjongCore
import SwiftUI

/// One hand in detail: big tile pattern, suit and shift controls, plain-English description, variants, your
/// record and the "Practise this hand" action (SPEC §11.7).
struct LineDetailView: View {
  let cardID: String
  let lineID: String

  @Environment(CardsStore.self) private var cards

  var body: some View {
    if let card = cards.card(id: cardID), let line = card.lines.first(where: { $0.id == lineID }) {
      LineDetailContent(card: card, line: line)
        .id(line.id)
    } else {
      EmptyStateView("Hand not found", systemImage: "rectangle.stack.badge.minus")
        .navigationTitle("Hand")
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}

private struct LineDetailContent: View {
  let card: Card
  let line: CardLine

  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(\.tabSwitcher) private var tabSwitcher
  @Environment(SettingsStore.self) private var settings
  @Environment(SessionsStore.self) private var sessions
  @Environment(HelperStore.self) private var helper

  @State private var model: LineDetailModel
  @State private var editorRequest: LineEditorRequest?
  @State private var suitTick = 0

  init(card: Card, line: CardLine) {
    self.card = card
    self.line = line
    _model = State(initialValue: LineDetailModel(line: line))
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        header
        patternCard
        practiseButton
        descriptionCard
        if line.variants.count > 1 { variantsCard }
        recordCard
      }
    }
    .navigationTitle(line.displayName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !card.builtIn {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Edit") { editorRequest = .edit(line.id) }
            .accessibilityIdentifier("line.edit")
        }
      }
    }
    .sheet(item: $editorRequest) { request in
      LineEditorSheet(cardID: card.id, request: request) { dismiss() }
    }
    .sensoryFeedback(.selection, trigger: suitTick)
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(line.displayName)
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      HStack(spacing: Spacing.sm) {
        Text(line.section)
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
        Text("\u{00B7}")
          .foregroundStyle(theme.textFaint)
          .accessibilityHidden(true)
        Text("\(line.points) pts")
          .font(Typography.body.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(theme.text)
        BadgeView(line.concealed ? .concealed : .exposed)
      }
    }
  }

  private var patternCard: some View {
    SectionCard("Example hand") {
      if let variant = currentVariant {
        ResolvedPatternView(
          variant: variant, target: model.current, size: .medium,
          accessibilityText: Notation.describe(variant, shift: line.shift, concealed: line.concealed)
        )
        .accessibilityIdentifier("line.pattern")
      }
      if !model.suitLegend.isEmpty {
        Text(model.suitLegend)
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
          .accessibilityIdentifier("line.legend")
      }
      if model.canTrySuits {
        Button {
          model.nextSuits()
          if settings.settings.haptics { suitTick += 1 }
        } label: {
          Label("Try other suits", systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
        .accessibilityIdentifier("line.trySuits")
      }
      if model.availableShifts.count > 1 {
        StepperField(
          "Shift numbers", value: shiftBinding, step: model.shiftStep,
          range: (model.availableShifts.first ?? 0)...(model.availableShifts.last ?? 0))
      }
    }
  }

  private var descriptionCard: some View {
    SectionCard("In plain English") {
      if let variant = currentVariant {
        Text(Notation.describe(variant, shift: line.shift, concealed: line.concealed))
          .font(Typography.body)
          .foregroundStyle(theme.text)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("line.description")
      }
    }
  }

  private var variantsCard: some View {
    SectionCard("Ways to make it") {
      ForEach(Array(line.variants.enumerated()), id: \.offset) { entry in
        Button {
          model.selectVariant(entry.offset)
        } label: {
          HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: entry.offset == model.variantIndex ? "largecircle.fill.circle" : "circle")
              .foregroundStyle(theme.primary)
              .accessibilityHidden(true)
            HandPatternView(variant: entry.element, line: line)
          }
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(entry.offset == model.variantIndex ? .isSelected : [])
        .accessibilityIdentifier("line.variant.\(entry.offset)")
      }
    }
  }

  private var recordCard: some View {
    SectionCard("Your record") {
      Text(winsText)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .accessibilityIdentifier("line.wins")
    }
  }

  private var practiseButton: some View {
    Button(action: practise) {
      Label("Practise this hand", systemImage: "lightbulb")
    }
    .buttonStyle(PrimaryButton(.primary, size: .large))
    .accessibilityIdentifier("line.practise")
  }

  // MARK: Helpers

  private var currentVariant: PatternVariant? {
    let index = model.current?.variantIndex ?? model.variantIndex
    if line.variants.indices.contains(index) { return line.variants[index] }
    return line.variants.first
  }

  private var shiftBinding: Binding<Int> {
    Binding(get: { model.k }, set: { model.setShift($0) })
  }

  private var winsText: String {
    let wins = Scoring.lineWins(cardID: card.id, sessions: sessions.sessions)[line.id] ?? 0
    switch wins {
    case 0: return "You haven't won this one yet."
    case 1: return "You've won this 1 time."
    default: return "You've won this \(wins) times."
    }
  }

  /// Pins the hand for the Helper, makes its card the active one, and opens the Helper tab.
  private func practise() {
    settings.update { $0.activeCardID = card.id }
    helper.pin(lineID: line.id)
    tabSwitcher.select(.helper)
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { LineDetailView(cardID: PracticeCard.card.id, lineID: PracticeCard.card.lines[9].id) }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .environment(stores.sessions)
    .environment(stores.helper)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { LineDetailView(cardID: PracticeCard.card.id, lineID: PracticeCard.card.lines[9].id) }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .environment(stores.sessions)
    .environment(stores.helper)
    .preferredColorScheme(.dark)
}
