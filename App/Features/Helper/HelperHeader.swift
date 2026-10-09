import MahjongCore
import SwiftUI

/// The Card chip (opens the card picker) and the Assist chip (a menu that changes the global setting).
struct HelperHeader: View {
  @Environment(SettingsStore.self) private var settings

  let cardName: String
  let onPickCard: () -> Void

  /// Off is not offered here: it would hide this very tab. It stays in Settings.
  private static let levels: [AssistLevel] = [.peek, .coach]

  var body: some View {
    HStack(spacing: Spacing.sm) {
      Button(action: onPickCard) {
        HeaderChipLabel(title: cardName, systemImage: "rectangle.stack")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Card: \(cardName)")
      .accessibilityHint("Choose a different card")
      .accessibilityIdentifier("helper.card")
      Spacer(minLength: Spacing.sm)
      Menu {
        ForEach(Self.levels, id: \.self) { level in
          Button {
            settings.update { $0.assistLevel = level }
          } label: {
            if settings.settings.assistLevel == level {
              Label(level.title, systemImage: "checkmark")
            } else {
              Text(level.title)
            }
          }
          .accessibilityIdentifier("assist.\(level.rawValue)")
        }
      } label: {
        HeaderChipLabel(title: settings.settings.assistLevel.title, systemImage: "lightbulb")
      }
      .accessibilityLabel("Assist level: \(settings.settings.assistLevel.title)")
      .accessibilityHint("Choose how much help to show")
      .accessibilityIdentifier("helper.assist")
    }
  }
}

private struct HeaderChipLabel: View {
  @Environment(\.theme) private var theme
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: Spacing.xs) {
      Image(systemName: systemImage)
        .font(Typography.small)
        .foregroundStyle(theme.primary)
        .accessibilityHidden(true)
      Text(title)
        .font(Typography.body.weight(.medium))
        .foregroundStyle(theme.text)
        .lineLimit(1)
      Image(systemName: "chevron.down")
        .font(.caption2.weight(.bold))
        .foregroundStyle(theme.textMuted)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, Spacing.md)
    .frame(minHeight: 44)
    .background(theme.surface, in: Capsule())
    .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
    .contentShape(Capsule())
  }
}

/// Lists every card (the Practice Card and the user's own) and makes the chosen one active.
struct CardPickerSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CardsStore.self) private var cards
  @Environment(SettingsStore.self) private var settings

  var body: some View {
    NavigationStack {
      List {
        ForEach(Array(cards.cards.enumerated()), id: \.element.id) { entry in
          let card = entry.element
          Button {
            settings.update { $0.activeCardID = card.id }
            dismiss()
          } label: {
            ListRowView(card.name, subtitle: subtitle(for: card)) {
              if card.id == settings.settings.activeCardID {
                Image(systemName: "checkmark")
                  .foregroundStyle(theme.primary)
                  .accessibilityHidden(true)
              }
            }
          }
          .buttonStyle(.plain)
          .listRowBackground(theme.surface)
          .accessibilityAddTraits(card.id == settings.settings.activeCardID ? .isSelected : [])
          .accessibilityIdentifier("helper.card.row.\(entry.offset)")
        }
      }
      .scrollContentBackground(.hidden)
      .background(theme.bg)
      .navigationTitle("Card")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("helper.card.done")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private func subtitle(for card: Card) -> String {
    let count = card.lines.count
    let hands = "\(count) \(count == 1 ? "hand" : "hands")"
    if card.builtIn { return "Built-in \u{00B7} \(hands)" }
    if let year = card.year { return "\(year) \u{00B7} \(hands)" }
    return hands
  }
}
