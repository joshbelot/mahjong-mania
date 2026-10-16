import MahjongCore
import SwiftUI

/// One rule: what it means, a live example (scoring rules), its choices, and the switch.
struct RuleDetailView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Binding var rules: RuleSet
  let ruleID: String

  @State private var editing = false
  @State private var confirmDelete = false

  private var rule: HouseRule? { rules.rule(ruleID) }
  private var definition: RuleDefinition? { RuleCatalog.definition(for: ruleID) }
  private var locked: Bool { definition?.locked ?? false }

  var body: some View {
    ScreenContainer {
      if let rule {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          let text = RuleTexts.text(for: rule)
          Text(text.title)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("rule.title")
          switchCard(rule)
          SectionCard("What it means") {
            Text(text.meaning)
              .font(Typography.body)
              .foregroundStyle(theme.text)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("rule.meaning")
          }
          if let example = RuleExamples.example(forRule: rule, in: rules) ?? text.example {
            SectionCard("Example") {
              Text(example)
                .font(Typography.body)
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("rule.example")
            }
          }
          if let definition, !definition.multipleChoices.isEmpty { choicesCard(definition, rule) }
          if rule.id == RuleID.jokerless { jokerlessCard(rule) }
          if rule.isCustom { customCard }
        }
      }
    }
    .navigationTitle("Rule")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $editing) {
      RuleEditorSheet(rules: $rules, editingID: ruleID)
    }
    .confirmationDialog("Delete this rule?", isPresented: $confirmDelete, titleVisibility: .visible) {
      Button("Delete rule", role: .destructive) {
        rules.removeCustom(id: ruleID)
        dismiss()
      }
      .accessibilityIdentifier("rule.delete.confirm")
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("It will be removed from this rule book.")
    }
  }

  // MARK: Cards

  @ViewBuilder
  private func switchCard(_ rule: HouseRule) -> some View {
    SectionCard {
      if locked {
        HStack {
          Text("Always on")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.text)
          Spacer()
          Image(systemName: "lock.fill")
            .foregroundStyle(theme.textMuted)
            .accessibilityHidden(true)
        }
        Text(RuleTexts.lockedNote)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else if rule.isCustom && rule.custom?.effect == nil {
        Text("A note for the table. It doesn't change any payments.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else {
        GameToggleRow(
          title: rule.isEnabled ? "On" : "Off",
          subtitle: rule.isEnabled ? nil : "Switched off, so it doesn't change the game.",
          isOn: Binding(
            get: { rule.isEnabled }, set: { rules.setEnabled(ruleID, $0) }),
          identifier: "rule.toggle")
      }
    }
  }

  private func choicesCard(_ definition: RuleDefinition, _ rule: HouseRule) -> some View {
    SectionCard("How much") {
      FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
        ForEach(choices(definition, rule), id: \.self) { value in
          ChipView(RuleTexts.multipleName(value), isSelected: rule.multiple == value) {
            rules.update(ruleID) {
              $0.multiple = value
              if !locked { $0.isEnabled = true }
            }
          }
          .accessibilityIdentifier("rule.choice.\(value)")
        }
      }
    }
  }

  /// The offered values, plus the stored one if an older file holds something else.
  private func choices(_ definition: RuleDefinition, _ rule: HouseRule) -> [Int] {
    var values = definition.multipleChoices
    if let current = rule.multiple, !values.contains(current) { values.append(current) }
    return values
  }

  private func jokerlessCard(_ rule: HouseRule) -> some View {
    SectionCard("Singles & pairs") {
      GameToggleRow(
        title: "Also for singles-and-pairs hands",
        subtitle: "Those hands can't use jokers anyway, so they don't get the bonus unless you switch this on.",
        isOn: Binding(
          get: { rule.includeNoJokerHands ?? false },
          set: { value in rules.update(ruleID) { $0.includeNoJokerHands = value } }),
        identifier: "rules.noJokerBonus")
    }
  }

  private var customCard: some View {
    SectionCard {
      AdaptiveStack(spacing: Spacing.md) {
        Button("Edit") { editing = true }
          .buttonStyle(PrimaryButton(.secondary))
          .accessibilityIdentifier("rule.edit")
        Button("Delete rule", role: .destructive) { confirmDelete = true }
          .buttonStyle(PrimaryButton(.destructive))
          .accessibilityIdentifier("rule.delete")
      }
    }
  }
}
