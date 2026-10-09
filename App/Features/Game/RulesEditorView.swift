import MahjongCore
import SwiftUI

/// Edits a `RuleSet` in place through a binding (multipliers, jokerless bonus, optional money), and can
/// save it as a named ruleset or as the default for new game nights.
struct RulesEditorView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Binding var rules: RuleSet
  /// Show the money switch and ¢/point (the scoreboard sheet does; session setup has its own row).
  var showsMoney = false
  @State private var message: String?

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        presetCard
        multipliersCard
        jokerlessCard
        if showsMoney { moneyCard }
        saveCard
      }
    }
    .navigationTitle("Rules")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Cards

  private var presetCard: some View {
    SectionCard("Ruleset") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text(RulesSummary.title(rules))
          .font(Typography.h2)
          .foregroundStyle(theme.text)
        Text(RulesSummary.text(rules))
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        Menu {
          Button("Standard") { load(.standard) }
          ForEach(settings.settings.savedRules) { saved in
            Button(saved.name) { load(saved) }
          }
        } label: {
          Label("Load a ruleset", systemImage: "list.bullet")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.primary)
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("rules.load")
      }
    }
  }

  private var multipliersCard: some View {
    SectionCard("Payments") {
      VStack(spacing: 0) {
        StepperField("Discarder pays \u{00D7}", value: $rules.discarderMultiplier, range: 1...10)
        Divider().overlay(theme.border)
        StepperField("Others on a discard \u{00D7}", value: $rules.othersOnDiscardMultiplier, range: 0...10)
        Divider().overlay(theme.border)
        StepperField("Self-pick \u{00D7}", value: $rules.selfPickMultiplier, range: 1...10)
        Divider().overlay(theme.border)
        StepperField("Jokerless \u{00D7}", value: $rules.jokerlessMultiplier, range: 1...10)
      }
    }
  }

  private var jokerlessCard: some View {
    SectionCard("Singles & Pairs") {
      GameToggleRow(
        title: "Jokerless bonus",
        subtitle: "Pay the jokerless bonus on hands with no joker groups. Off by default, because those hands are always jokerless.",
        isOn: $rules.jokerlessBonusForNoJokerLines, identifier: "rules.noJokerBonus")
    }
  }

  private var moneyCard: some View {
    SectionCard("Money") {
      VStack(spacing: 0) {
        GameToggleRow(title: "Play for money", isOn: $rules.money.enabled, identifier: "rules.money")
        if rules.money.enabled {
          Divider().overlay(theme.border)
          StepperField("Cents per point", value: $rules.money.centsPerPoint, range: 1...100, unit: "\u{00A2}")
        }
      }
    }
  }

  private var saveCard: some View {
    SectionCard("Save") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        TextField("Ruleset name", text: $rules.name)
          .textInputAutocapitalization(.words)
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .accessibilityIdentifier("rules.name")
        HStack(spacing: Spacing.md) {
          Button("Save ruleset") { saveNamed() }
            .buttonStyle(PrimaryButton(.secondary))
            .accessibilityIdentifier("rules.save")
          Button("Use as default") { makeDefault() }
            .buttonStyle(PrimaryButton(.secondary))
            .accessibilityIdentifier("rules.default")
        }
        if let message {
          Text(message)
            .font(Typography.small)
            .foregroundStyle(theme.success)
        }
      }
    }
  }

  // MARK: Actions

  /// Takes another ruleset's payout rules but keeps this game's money settings.
  private func load(_ preset: RuleSet) {
    var next = preset
    next.money = rules.money
    rules = next
    message = nil
  }

  private func saveNamed() {
    let trimmed = rules.name.trimmingCharacters(in: .whitespacesAndNewlines)
    var saved = rules
    saved.name = trimmed.isEmpty ? "My rules" : trimmed
    saved.id = UUID().uuidString
    rules.name = saved.name
    settings.update { value in
      value.savedRules.removeAll { $0.name == saved.name }
      value.savedRules.append(saved)
    }
    message = "Saved \u{201C}\(saved.name)\u{201D}"
  }

  private func makeDefault() {
    let current = rules
    settings.update { $0.defaultRules = current }
    message = "These rules will be used for new game nights."
  }
}

#if DEBUG
  private struct RulesEditorPreview: View {
    @State private var rules = RuleSet.standard

    var body: some View {
      NavigationStack { RulesEditorView(rules: $rules, showsMoney: true) }
    }
  }

  #Preview("Light") {
    RulesEditorPreview()
      .gameStores(AppStores.inMemory())
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    RulesEditorPreview()
      .gameStores(AppStores.inMemory())
      .preferredColorScheme(.dark)
  }
#endif
