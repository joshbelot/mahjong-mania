import MahjongCore
import SwiftUI

/// Adds or edits a custom rule: a note for the table, or a scoring rule built from three plain
/// pickers that read as a sentence ("On a self-pick, everyone pays double.").
struct RuleEditorSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(SettingsStore.self) private var settings
  @Environment(CardsStore.self) private var cards
  @Binding var rules: RuleSet
  /// The custom rule being edited, or nil to add one.
  let editingID: String?

  private enum Kind: Hashable { case note, scoring }
  private enum When: Hashable { case always, selfPick, discard, jokerless, concealed, east, section, line }
  private enum Pays: Hashable { case double, triple, quadruple, extra }

  @State private var kind: Kind = .scoring
  @State private var title = ""
  @State private var titleEdited = false
  @State private var text = ""
  @State private var when: When = .always
  @State private var section = ""
  @State private var lineID = ""
  @State private var payers: PayerScope = .everyone
  @State private var pays: Pays = .double
  @State private var extraPoints = 10
  @State private var loaded = false

  private var card: Card? { cards.card(id: settings.settings.activeCardID) ?? cards.cards.first }
  private var sections: [String] { card?.sections ?? [] }
  private var lines: [CardLine] { card?.lines ?? [] }

  private var whenOptions: [(When, String)] {
    var options: [(When, String)] = [
      (.always, "any win"), (.selfPick, "a self-pick"), (.discard, "a win from a discard"),
      (.jokerless, "a jokerless hand"), (.concealed, "a concealed hand"), (.east, "East wins"),
    ]
    if !sections.isEmpty { options.append((.section, "a hand from a section\u{2026}")) }
    if !lines.isEmpty { options.append((.line, "this hand\u{2026}")) }
    return options
  }

  private var condition: RuleCondition {
    switch when {
    case .always: return .always
    case .selfPick: return .selfPick
    case .discard: return .discard
    case .jokerless: return .jokerless
    case .concealed: return .concealedHand
    case .east: return .eastWins
    case .section: return .section(section.isEmpty ? (sections.first ?? "") : section)
    case .line:
      let chosen = lines.first { $0.id == lineID } ?? lines.first
      return .line(id: chosen?.id ?? "", label: chosen?.displayName ?? "")
    }
  }

  private var action: RuleAction {
    switch pays {
    case .double: return .multiply(2)
    case .triple: return .multiply(3)
    case .quadruple: return .multiply(4)
    case .extra: return .addPoints(extraPoints)
    }
  }

  private var effect: CustomEffect { CustomEffect(condition: condition, payers: payers, action: action) }

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          if editingID == nil { kindCard }
          if kind == .scoring { scoringCard } else { noteCard }
          titleCard
          if kind == .scoring { exampleCard }
        }
      }
      .navigationTitle(editingID == nil ? "Add a rule" : "Edit rule")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.accessibilityIdentifier("ruleEditor.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(!canSave)
            .accessibilityIdentifier("ruleEditor.save")
        }
      }
      .onAppear(perform: load)
      .onChange(of: effect) { refreshTitle() }
      .onChange(of: kind) { refreshTitle() }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  // MARK: Cards

  private var kindCard: some View {
    SectionCard("What kind of rule?") {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
          ChipView("A scoring rule", isSelected: kind == .scoring) { kind = .scoring }
            .accessibilityIdentifier("ruleEditor.kind.scoring")
          ChipView("A note for our table", isSelected: kind == .note) { kind = .note }
            .accessibilityIdentifier("ruleEditor.kind.note")
        }
        Text(
          kind == .scoring
            ? "Changes what people pay, and shows up in the explanation of each hand."
            : "Written down so everyone remembers it. It doesn't change any payments."
        )
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      }
    }
  }

  private var scoringCard: some View {
    SectionCard("When, who, how much") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text("When")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        Picker("When", selection: $when) {
          ForEach(whenOptions, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.menu)
        .tint(theme.primary)
        .accessibilityIdentifier("ruleEditor.when")
        if when == .section {
          Picker("Section", selection: Binding(get: { section.isEmpty ? (sections.first ?? "") : section }, set: { section = $0 })) {
            ForEach(sections, id: \.self) { Text($0).tag($0) }
          }
          .pickerStyle(.menu)
          .tint(theme.primary)
          .accessibilityIdentifier("ruleEditor.section")
        }
        if when == .line {
          Picker("Hand", selection: Binding(get: { lineID.isEmpty ? (lines.first?.id ?? "") : lineID }, set: { lineID = $0 })) {
            ForEach(lines, id: \.id) { Text($0.displayName).tag($0.id) }
          }
          .pickerStyle(.menu)
          .tint(theme.primary)
          .accessibilityIdentifier("ruleEditor.line")
        }
        Text("Then")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
          ChipView("everyone", isSelected: payers == .everyone) { payers = .everyone }
            .accessibilityIdentifier("ruleEditor.payers.everyone")
          ChipView("the thrower", isSelected: payers == .discarderOnly) { payers = .discarderOnly }
            .accessibilityIdentifier("ruleEditor.payers.thrower")
          ChipView("everyone except the thrower", isSelected: payers == .everyoneButDiscarder) {
            payers = .everyoneButDiscarder
          }
          .accessibilityIdentifier("ruleEditor.payers.others")
        }
        Text("Pays")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
          ChipView("double", isSelected: pays == .double) { pays = .double }
            .accessibilityIdentifier("ruleEditor.pays.double")
          ChipView("triple", isSelected: pays == .triple) { pays = .triple }
            .accessibilityIdentifier("ruleEditor.pays.triple")
          ChipView("quadruple", isSelected: pays == .quadruple) { pays = .quadruple }
            .accessibilityIdentifier("ruleEditor.pays.quadruple")
          ChipView("extra points", isSelected: pays == .extra) { pays = .extra }
            .accessibilityIdentifier("ruleEditor.pays.extra")
        }
        if pays == .extra {
          StepperField("Extra points each", value: $extraPoints, range: 1...200)
        }
        Text("A sentence you can read out: \(RuleSentences.sentence(for: effect))")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .accessibilityIdentifier("ruleEditor.sentence")
      }
    }
  }

  private var noteCard: some View {
    SectionCard("The note") {
      TextField("What is the rule?", text: $text, axis: .vertical)
        .lineLimit(3...8)
        .padding(Spacing.md)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityIdentifier("ruleEditor.text")
    }
  }

  private var titleCard: some View {
    SectionCard("Name") {
      TextField(kind == .scoring ? "Rule name" : "Rule name, e.g. No phones", text: $title)
        .textInputAutocapitalization(.sentences)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 44)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        .onChange(of: title) { _, newValue in
          if kind == .scoring && newValue != RuleSentences.autoTitle(for: effect) { titleEdited = true }
        }
        .accessibilityIdentifier("ruleEditor.title")
    }
  }

  private var exampleCard: some View {
    var preview = rules
    var candidate = HouseRule(
      id: editingID ?? "custom.preview",
      custom: CustomRule(title: title, text: text, effect: effect))
    candidate.isEnabled = true
    if let editingID { preview.removeCustom(id: editingID) }
    preview.addCustom(candidate)
    return SectionCard("Example") {
      Text(RuleExamples.text(RuleExamples.scenario(for: effect.condition), rules: preview))
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("ruleEditor.example")
    }
  }

  // MARK: Actions

  private func refreshTitle() {
    guard kind == .scoring, !titleEdited else { return }
    title = RuleSentences.autoTitle(for: effect)
  }

  private func load() {
    guard !loaded else { return }
    loaded = true
    if let editingID, let existing = rules.rule(editingID), let custom = existing.custom {
      title = custom.title
      text = custom.text
      if let effect = custom.effect {
        kind = .scoring
        payers = effect.payers
        switch effect.condition {
        case .always: when = .always
        case .selfPick: when = .selfPick
        case .discard: when = .discard
        case .jokerless: when = .jokerless
        case .concealedHand: when = .concealed
        case .eastWins: when = .east
        case .section(let name):
          when = .section
          section = name
        case .line(let id, _):
          when = .line
          lineID = id
        }
        switch effect.action {
        case .multiply(let n): pays = n == 3 ? .triple : (n == 4 ? .quadruple : .double)
        case .addPoints(let n):
          pays = .extra
          extraPoints = n
        }
        titleEdited = custom.title != RuleSentences.autoTitle(for: effect)
      } else {
        kind = .note
      }
    } else {
      title = RuleSentences.autoTitle(for: effect)
    }
  }

  private func save() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let custom = CustomRule(
      title: trimmedTitle, text: kind == .note ? trimmedText : trimmedText,
      effect: kind == .scoring ? effect : nil)
    if let editingID {
      rules.update(editingID) { $0.custom = custom }
    } else {
      rules.addCustom(HouseRule(id: HouseRule.newCustomID(), isEnabled: true, custom: custom))
    }
    dismiss()
  }
}
