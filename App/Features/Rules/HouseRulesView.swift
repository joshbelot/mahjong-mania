import MahjongCore
import SwiftUI

/// The rule book (SPEC §17.4): every rule as a plain sentence the user can read, switch on or off,
/// adjust, and add to. Edits the `RuleSet` it is given: the default book (Settings), the one for a
/// new game night (setup), or a running game night (the scoreboard).
struct HouseRulesView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Binding var rules: RuleSet
  /// Show the money switch and ¢/point (the scoreboard sheet does; session setup has its own row).
  var showsMoney = false

  @State private var message: String?
  @State private var showingAdd = false

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        bookCard
        ForEach(RuleCategory.allCases, id: \.self) { category in
          categoryCard(category)
        }
        ourRulesCard
        if showsMoney { moneyCard }
        saveCard
      }
    }
    .navigationTitle("House rules")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showingAdd) {
      RuleEditorSheet(rules: $rules, editingID: nil)
    }
  }

  // MARK: Cards

  private var bookCard: some View {
    SectionCard("Rule book") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text(RulesSummary.title(rules))
          .font(Typography.h2)
          .foregroundStyle(theme.text)
          .accessibilityIdentifier("rules.title")
        Text(RulesSummary.text(rules))
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        Text("Tap a rule to read what it means. Switch rules on or off, or change how much they pay.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        Menu {
          Button("Standard") { load(.standard) }
          ForEach(settings.settings.savedRules) { saved in
            Button(saved.name) { load(saved) }
          }
        } label: {
          Label("Load a rule book", systemImage: "list.bullet")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.primary)
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("rules.load")
      }
    }
  }

  private func categoryCard(_ category: RuleCategory) -> some View {
    let definitions = RuleCatalog.builtIns.filter { $0.category == category }
    return SectionCard(category.title) {
      VStack(spacing: 0) {
        ForEach(Array(definitions.enumerated()), id: \.element.id) { entry in
          if entry.offset > 0 { Divider().overlay(theme.border) }
          if let rule = rules.rule(entry.element.id) {
            RuleRow(rules: $rules, rule: rule, locked: entry.element.locked)
          }
        }
      }
    }
  }

  private var ourRulesCard: some View {
    SectionCard("Our house rules") {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        if rules.customRules.isEmpty {
          Text("Add a note for your table, or a scoring rule that changes what people pay.")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(rules.customRules.enumerated()), id: \.element.id) { entry in
              if entry.offset > 0 { Divider().overlay(theme.border) }
              RuleRow(rules: $rules, rule: entry.element, locked: false)
            }
          }
        }
        Button {
          showingAdd = true
        } label: {
          Label("Add a rule", systemImage: "plus")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButton(.secondary))
        .accessibilityIdentifier("rules.add")
      }
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
        TextField("Rule book name", text: $rules.name)
          .textInputAutocapitalization(.words)
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .accessibilityIdentifier("rules.name")
        AdaptiveStack(spacing: Spacing.md) {
          Button("Save as a rule book") { saveNamed() }
            .buttonStyle(PrimaryButton(.secondary))
            .accessibilityIdentifier("rules.save")
          Button("Use for new game nights") { makeDefault() }
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

  /// Takes another rule book's rules but keeps this game's money settings.
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

/// One rule in the book: its sentence and current choice (opens the detail), then a switch or an
/// "Always on" badge.
private struct RuleRow: View {
  @Environment(\.theme) private var theme
  @Binding var rules: RuleSet
  let rule: HouseRule
  let locked: Bool

  private var enabled: Binding<Bool> {
    Binding(
      get: { rule.isEnabled },
      set: { newValue in rules.setEnabled(rule.id, newValue) })
  }

  var body: some View {
    let text = RuleTexts.text(for: rule)
    AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.sm) {
      NavigationLink {
        RuleDetailView(rules: $rules, ruleID: rule.id)
      } label: {
        HStack(spacing: Spacing.sm) {
          VStack(alignment: .leading, spacing: 2) {
            Text(text.title)
              .font(Typography.body)
              .foregroundStyle(rule.isEnabled || locked ? theme.text : theme.textMuted)
              .multilineTextAlignment(.leading)
            // The sentence already says the choice for the scoring rules; custom rules and blanks
            // need the extra line, and any switched-off rule says so.
            if let choice = RuleTexts.choiceText(for: rule),
              rule.isCustom || rule.id == RuleID.blanks || !rule.isEnabled
            {
              Text(rule.isEnabled ? choice : "Off")
                .font(Typography.small)
                .foregroundStyle(theme.textMuted)
                .multilineTextAlignment(.leading)
            }
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.textFaint)
            .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("rule.row.\(rule.id)")
      if locked {
        Text("Always on")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
          .padding(.horizontal, Spacing.sm)
          .padding(.vertical, 4)
          .background(theme.surfaceAlt, in: Capsule())
          .accessibilityIdentifier("rule.locked.\(rule.id)")
      } else if rule.isCustom && rule.custom?.effect == nil {
        EmptyView()
      } else {
        Toggle(text.title, isOn: enabled)
          .labelsHidden()
          .tint(theme.primary)
          .accessibilityIdentifier("rule.toggle.\(rule.id)")
      }
    }
    .padding(.vertical, 4)
  }
}
