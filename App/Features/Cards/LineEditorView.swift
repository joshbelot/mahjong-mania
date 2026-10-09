import MahjongCore
import SwiftUI

/// Modal editor for one hand of a user card (SPEC §11.7).
struct LineEditorView: View {
  private enum Field: Hashable {
    case notation, name, section
  }

  let cardID: String
  /// The line being edited, or nil for a new hand.
  let lineID: String?
  let original: LineEditorModel
  var onSaved: () -> Void = {}

  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @Environment(CardsStore.self) private var cards
  @Environment(SettingsStore.self) private var settings

  @State private var model: LineEditorModel
  @State private var keyTick = 0
  @FocusState private var focus: Field?

  init(cardID: String, lineID: String?, model: LineEditorModel, onSaved: @escaping () -> Void = {}) {
    self.cardID = cardID
    self.lineID = lineID
    self.original = model
    self.onSaved = onSaved
    _model = State(initialValue: model)
  }

  var body: some View {
    let status = model.status
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        if !settings.settings.cardNoticeSeen { noticeBanner }
        SectionCard("Hand") {
          notationField
          liveArea(status)
        }
        SectionCard("Details") {
          detailFields
        }
      }
    }
    .navigationTitle(lineID == nil ? "New hand" : "Edit hand")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
          .accessibilityIdentifier("editor.cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: save)
          .disabled(!model.canSave)
          .accessibilityIdentifier("editor.save")
      }
      ToolbarItemGroup(placement: .keyboard) {
        if focus == .notation {
          keyRow
        }
        Button("Done") { focus = nil }
          .accessibilityIdentifier("editor.keyboardDone")
      }
    }
    .interactiveDismissDisabled(model != original)
    .haptic(.selection, trigger: keyTick)
    .onChange(of: model.notation) { _, newValue in
      if newValue.contains(where: { $0.isNewline }) {
        model.notation = String(newValue.filter { !$0.isNewline })
        focus = nil
      }
    }
  }

  // MARK: Copyright notice

  private var noticeBanner: some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(theme.gold)
        .accessibilityHidden(true)
      Text("Enter hands from a card you own. Please don't publicly share copyrighted cards.")
        .font(Typography.small)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button("Got it") {
        settings.update { $0.cardNoticeSeen = true }
      }
      .font(Typography.small.weight(.semibold))
      .foregroundStyle(theme.primary)
      .frame(minHeight: 44)
      .accessibilityIdentifier("editor.noticeDismiss")
    }
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("editor.notice")
  }

  // MARK: Notation

  private var notationField: some View {
    TextField("FF 2026/x 2222/y 6666/y", text: $model.notation, axis: .vertical)
      .font(.system(.body, design: .monospaced))
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .lineLimit(1...4)
      .focused($focus, equals: .notation)
      .padding(Spacing.md)
      .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
      .accessibilityLabel("Notation")
      .accessibilityIdentifier("editor.notation")
  }

  @ViewBuilder
  private func liveArea(_ status: EditorStatus) -> some View {
    switch status {
    case .empty(let hint):
      Text(hint)
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .accessibilityIdentifier("editor.hint")
    case .invalid(let problems):
      VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(Array(problems.prefix(3).enumerated()), id: \.offset) { entry in
          problemView(entry.element)
        }
        if problems.count > 3 {
          Text("and \(problems.count - 3) more")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("editor.error")
    case .valid(let line):
      VStack(alignment: .leading, spacing: Spacing.md) {
        if let variant = line.variants.first {
          ResolvedPatternView(variant: variant, target: LineDetailModel(line: line).current, size: .small)
        }
        ForEach(Array(line.variants.enumerated()), id: \.offset) { entry in
          let text = Notation.describe(entry.element, shift: line.shift, concealed: line.concealed)
          Text(line.variants.count > 1 ? "Option \(entry.offset + 1): \(text)" : text)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(spacing: Spacing.sm) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(theme.success)
            .accessibilityHidden(true)
          Text("14 tiles \u{2713}")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.success)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("editor.valid")
      }
    }
  }

  /// The notation with a `^~~` marker under the offending characters, then the message.
  private func problemView(_ problem: EditorProblem) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      if let range = problem.range {
        ScrollView(.horizontal, showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            Text(Self.preserveSpaces(model.cleanNotation))
              .foregroundStyle(theme.text)
            Text(Self.preserveSpaces(LineEditorModel.marker(for: range)))
              .foregroundStyle(theme.danger)
          }
          .font(.system(.footnote, design: .monospaced).weight(.semibold))
          .fixedSize()
        }
        .accessibilityHidden(true)
      }
      Label {
        Text(problem.message)
          .font(Typography.small)
          .foregroundStyle(theme.danger)
          .frame(maxWidth: .infinity, alignment: .leading)
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(theme.danger)
      }
    }
  }

  /// Plain spaces collapse at the edges of a `Text`; no-break spaces keep the caret aligned.
  private static func preserveSpaces(_ text: String) -> String {
    text.replacingOccurrences(of: " ", with: "\u{00A0}")
  }

  // MARK: Details

  @ViewBuilder
  private var detailFields: some View {
    HStack {
      Text("Section")
        .font(Typography.body)
        .foregroundStyle(theme.text)
      Spacer(minLength: Spacing.sm)
      Picker("Section", selection: $model.sectionChoice) {
        ForEach(model.availableSections, id: \.self) { section in
          Text(section).tag(SectionChoice.existing(section))
        }
        Text("New section\u{2026}").tag(SectionChoice.new)
      }
      .pickerStyle(.menu)
      .tint(theme.primary)
      .accessibilityIdentifier("editor.section")
    }
    .frame(minHeight: 44)
    if model.sectionChoice == .new {
      TextField("Section name", text: $model.newSectionName)
        .focused($focus, equals: .section)
        .textInputAutocapitalization(.words)
        .padding(Spacing.md)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityIdentifier("editor.newSection")
      if let problem = model.sectionProblem {
        Text(problem)
          .font(Typography.small)
          .foregroundStyle(theme.danger)
      }
    }

    TextField("Name (optional)", text: $model.name)
      .focused($focus, equals: .name)
      .textInputAutocapitalization(.words)
      .padding(Spacing.md)
      .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
      .accessibilityIdentifier("editor.name")

    StepperField("Points", value: $model.points, step: 5, range: LineEditorModel.pointsRange, unit: "pts")
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Spacing.sm) {
        ForEach(LineEditorModel.quickPoints, id: \.self) { value in
          ChipView("\(value)", isSelected: model.points == value) { model.points = value }
        }
      }
    }

    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text("Exposed or concealed")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      SegmentedPicker("Exposed or concealed", selection: $model.concealed, options: [false, true]) {
        $0 ? "Concealed" : "Exposed"
      }
      .accessibilityIdentifier("editor.exposure")
    }

    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text("Shift")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      SegmentedPicker(
        "Shift", selection: $model.shift, options: [Shift.none, Shift.consecutive, Shift.parity]
      ) { shift in
        switch shift {
        case .none: return "None"
        case .consecutive: return "Consecutive"
        case .parity: return "Odd-even"
        }
      }
      .accessibilityIdentifier("editor.shift")
    }
  }

  // MARK: Key row

  private var keyRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Spacing.xs) {
        ForEach(LineEditorModel.tileKeys, id: \.self) { key in
          keyButton(key, label: key, ink: theme.text)
        }
        ForEach(LineEditorModel.suitKeys, id: \.self) { key in
          keyButton(key, label: key, ink: suitInk(key))
        }
        ForEach(LineEditorModel.operatorKeys, id: \.self) { key in
          keyButton(key, label: key, ink: theme.textMuted)
        }
        Button {
          press(.space)
        } label: {
          Image(systemName: "space")
            .foregroundStyle(theme.text)
            .frame(minWidth: 44, minHeight: 36)
        }
        .accessibilityLabel("Space")
        .accessibilityIdentifier("key.space")
        Button {
          press(.backspace)
        } label: {
          Image(systemName: "delete.left")
            .foregroundStyle(theme.text)
            .frame(minWidth: 44, minHeight: 36)
        }
        .accessibilityLabel("Delete")
        .accessibilityIdentifier("key.delete")
      }
    }
  }

  private func keyButton(_ key: String, label: String, ink: Color) -> some View {
    Button {
      press(.text(key))
    } label: {
      Text(label)
        .font(.system(.body, design: .monospaced).weight(.bold))
        .foregroundStyle(ink)
        .frame(minWidth: 36, minHeight: 36)
        .padding(.horizontal, 2)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm))
    }
    .accessibilityLabel(Self.spokenKey(key))
    .accessibilityIdentifier("key.\(key)")
  }

  private func suitInk(_ key: String) -> Color {
    switch key {
    case "/x": return theme.varA
    case "/y": return theme.varB
    case "/z": return theme.varC
    case "/c": return theme.suitC
    case "/b": return theme.suitB
    default: return theme.suitD
    }
  }

  private static func spokenKey(_ key: String) -> String {
    switch key {
    case "F": return "Flower"
    case "N": return "North"
    case "E": return "East"
    case "W": return "West"
    case "S": return "South"
    case "R": return "Red Dragon"
    case "G": return "Green Dragon"
    case "0": return "Soap"
    case "D": return "Matching dragon"
    case "/x": return "Suit A, any suit"
    case "/y": return "Suit B, any suit"
    case "/z": return "Suit C, any suit"
    case "/c": return "Cracks"
    case "/b": return "Bams"
    case "/d": return "Dots"
    case "|": return "Or another way"
    case "+": return "Plus"
    case "=": return "Equals"
    default: return key
    }
  }

  private func press(_ key: EditorKey) {
    model.press(key)
    keyTick += 1
  }

  // MARK: Save

  private func save() {
    guard let line = model.validLine, let card = cards.card(id: cardID) else { return }
    let text: String
    if let lineID {
      text = CardEditing.text(replacing: lineID, with: line, in: card)
    } else {
      text = CardEditing.text(adding: line, to: card)
    }
    cards.updateText(id: cardID, text: text)
    if !settings.settings.cardNoticeSeen { settings.update { $0.cardNoticeSeen = true } }
    onSaved()
    dismiss()
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack {
    LineEditorView(
      cardID: "x", lineID: nil,
      model: {
        var model = LineEditorModel(availableSections: ["Year"])
        model.notation = "FF 2026/x 2222/y 6666"
        return model
      }())
  }
  .environment(\.theme, Theme.standard)
  .environment(stores.cards)
  .environment(stores.settings)
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack {
    LineEditorView(
      cardID: "x", lineID: nil,
      model: {
        var model = LineEditorModel(availableSections: ["Year"])
        model.notation = "FF 2026/x 2222/y 6666/y"
        return model
      }())
  }
  .environment(\.theme, Theme.standard)
  .environment(stores.cards)
  .environment(stores.settings)
  .preferredColorScheme(.dark)
}
