import MahjongCore
import SwiftUI

/// What one group of the guided form is, in words a player uses.
enum GuidedKind: String, CaseIterable, Hashable, Sendable {
  case number, wind, dragon, flower, matchingDragon

  var title: String {
    switch self {
    case .number: return "Number"
    case .wind: return "Wind"
    case .dragon: return "Dragon or Soap"
    case .flower: return "Flower"
    case .matchingDragon: return "Matching dragon"
    }
  }
}

/// Suit choices of the guided form. A, B and C are three different suits; the others are one fixed suit.
enum GuidedSuit: String, CaseIterable, Hashable, Sendable {
  case a, b, c, cracks, bams, dots

  var ref: SuitRef {
    switch self {
    case .a: return .variable(.x)
    case .b: return .variable(.y)
    case .c: return .variable(.z)
    case .cracks: return .fixed(.cracks)
    case .bams: return .fixed(.bams)
    case .dots: return .fixed(.dots)
    }
  }

  init(_ ref: SuitRef) {
    switch ref {
    case .variable(.x): self = .a
    case .variable(.y): self = .b
    case .variable(.z): self = .c
    case .fixed(.cracks): self = .cracks
    case .fixed(.bams): self = .bams
    case .fixed(.dots): self = .dots
    }
  }

  var title: String {
    switch self {
    case .a: return "Suit A"
    case .b: return "Suit B"
    case .c: return "Suit C"
    case .cracks: return "Cracks"
    case .bams: return "Bams"
    case .dots: return "Dots"
    }
  }
}

/// A group's tile choice split into the pieces the form edits.
struct GuidedGroupDraft: Equatable, Sendable {
  var kind: GuidedKind
  var number = 1
  var suit = GuidedSuit.a
  var wind = Wind.north
  var dragon = Dragon.red

  init(_ spec: GroupSpec) {
    switch spec.tile {
    case .number(let value, let ref):
      kind = .number
      number = value
      suit = GuidedSuit(ref)
    case .matchingDragon(let ref):
      kind = .matchingDragon
      suit = GuidedSuit(ref)
    case .fixed(let tile):
      switch tile {
      case .wind(let wind):
        kind = .wind
        self.wind = wind
      case .dragon(let dragon):
        kind = .dragon
        self.dragon = dragon
      default:
        kind = .flower
      }
    }
  }

  var tile: TileSpec {
    switch kind {
    case .number: return .number(number, suit.ref)
    case .matchingDragon: return .matchingDragon(suit.ref)
    case .wind: return .fixed(.wind(wind))
    case .dragon: return .fixed(.dragon(dragon))
    case .flower: return .fixed(.flower)
    }
  }
}

/// State behind the guided hand editor: the shared fields of `LineEditorModel` for the section, plus the
/// foundation-only `GuidedLine` that is written back as ordinary notation.
struct GuidedEditorModel: Equatable, Sendable {
  var base: LineEditorModel
  var line: GuidedLine

  init(availableSections: [String]) {
    base = LineEditorModel(availableSections: availableSections)
    line = GuidedLine()
  }

  init?(card: Card, editing existing: CardLine) {
    guard let guided = GuidedLine(line: existing) else { return nil }
    base = LineEditorModel(card: card, editing: existing)
    line = guided
  }

  /// Converts the advanced form when its notation is a valid, representable hand.
  init?(advanced model: LineEditorModel) {
    guard let valid = model.validLine, let guided = GuidedLine(line: valid) else { return nil }
    base = model
    line = guided
  }

  /// The advanced form with the same content, notation re-written from the groups.
  var advanced: LineEditorModel {
    var model = base
    model.notation = line.notation
    model.name = line.name
    model.points = line.points
    model.concealed = line.concealed
    model.shift = line.shift
    return model
  }

  var section: String { base.effectiveSection.isEmpty ? LineEditorModel.defaultSectionName : base.effectiveSection }

  var validation: GuidedLine.Validation { line.validate(section: section) }

  var validLine: CardLine? {
    guard base.sectionProblem == nil, case .valid(let valid, _) = validation else { return nil }
    return valid
  }

  var canSave: Bool { validLine != nil }

  // MARK: Editing groups

  mutating func addGroup(to alternative: Int) {
    guard line.alternatives.indices.contains(alternative) else { return }
    line.alternatives[alternative].append(GroupSpec(tile: .number(1, .variable(.x)), count: 2))
  }

  mutating func removeGroup(_ index: Int, from alternative: Int) {
    guard line.alternatives.indices.contains(alternative),
      line.alternatives[alternative].indices.contains(index)
    else { return }
    line.alternatives[alternative].remove(at: index)
  }

  mutating func moveGroup(_ index: Int, by offset: Int, in alternative: Int) {
    guard line.alternatives.indices.contains(alternative) else { return }
    let target = index + offset
    let groups = line.alternatives[alternative]
    guard groups.indices.contains(index), groups.indices.contains(target) else { return }
    line.alternatives[alternative].swapAt(index, target)
  }

  mutating func addAlternative() {
    guard line.alternatives.count < 4 else { return }
    line.alternatives.append(line.alternatives.last ?? [])
  }

  mutating func removeAlternative(_ index: Int) {
    guard line.alternatives.count > 1, line.alternatives.indices.contains(index) else { return }
    line.alternatives.remove(at: index)
  }
}

/// Guided entry for one hand: pick groups of tiles instead of typing notation (NEXT_WAVES §3.5).
struct GuidedHandEditorView: View {
  let cardID: String
  let lineID: String?
  let original: GuidedEditorModel
  var onSaved: () -> Void = {}
  /// Asks the host to show the notation editor with this content.
  var onAdvanced: (LineEditorModel) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @Environment(CardsStore.self) private var cards
  @Environment(SettingsStore.self) private var settings

  @State private var model: GuidedEditorModel
  @State private var showSwitchChoice = false
  @State private var tick = 0
  @FocusState private var nameFocused: Bool

  init(
    cardID: String, lineID: String?, model: GuidedEditorModel, onSaved: @escaping () -> Void = {},
    onAdvanced: @escaping (LineEditorModel) -> Void = { _ in }
  ) {
    self.cardID = cardID
    self.lineID = lineID
    self.original = model
    self.onSaved = onSaved
    self.onAdvanced = onAdvanced
    _model = State(initialValue: model)
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        if !settings.settings.cardNoticeSeen { noticeBanner }
        ForEach(Array(model.line.alternatives.enumerated()), id: \.offset) { entry in
          alternativeCard(index: entry.offset)
        }
        if model.line.alternatives.count < 4 { addAlternativeButton }
        previewCard
        detailsCard
        Button {
          if model != original { showSwitchChoice = true } else { onAdvanced(model.advanced) }
        } label: {
          Label("Advanced notation", systemImage: "chevron.left.forwardslash.chevron.right")
            .frame(minHeight: 44)
        }
        .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
        .accessibilityIdentifier("guided.advanced")
      }
    }
    .navigationTitle(lineID == nil ? "Build a hand" : "Edit hand")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }.accessibilityIdentifier("editor.cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: save)
          .disabled(!model.canSave)
          .accessibilityIdentifier("editor.save")
      }
    }
    .confirmationDialog("Switch to notation?", isPresented: $showSwitchChoice, titleVisibility: .visible) {
      Button("Apply my changes") { onAdvanced(model.advanced) }
      Button("Discard my changes", role: .destructive) { onAdvanced(original.advanced) }
      Button("Keep editing", role: .cancel) {}
    } message: {
      Text("You have changes that are not saved.")
    }
    .interactiveDismissDisabled(model != original)
    .haptic(.selection, trigger: tick)
  }

  // MARK: Notice

  private var noticeBanner: some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: "info.circle.fill").foregroundStyle(theme.gold).accessibilityHidden(true)
      Text("Enter hands from a card you own. Please don't publicly share copyrighted cards.")
        .font(Typography.small)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button("Got it") { settings.update { $0.cardNoticeSeen = true } }
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

  // MARK: Groups

  private func alternativeCard(index: Int) -> some View {
    let many = model.line.alternatives.count > 1
    let count = model.line.tileCount(ofAlternative: index)
    return SectionCard(many ? "Way \(index + 1)" : "Groups of tiles") {
      if index == 0 {
        Text("A hand is 14 tiles. Add groups of the same tile, like a Pung of three or a Pair of two.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
      ForEach(Array(model.line.alternatives[index].enumerated()), id: \.offset) { entry in
        groupRow(alternative: index, index: entry.offset, spec: entry.element)
      }
      Button {
        model.addGroup(to: index)
        tick += 1
      } label: {
        Label("Add a group", systemImage: "plus.circle.fill")
          .font(Typography.body.weight(.semibold))
          .frame(minHeight: 44, alignment: .leading)
      }
      .accessibilityIdentifier("guided.addGroup.\(index)")
      Text("\(count) of \(GuidedLine.tilesPerHand) tiles")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(count == GuidedLine.tilesPerHand ? theme.success : theme.textMuted)
        .accessibilityIdentifier("guided.count.\(index)")
      if many {
        Button("Remove this way", role: .destructive) { model.removeAlternative(index) }
          .frame(minHeight: 44)
          .accessibilityIdentifier("guided.removeWay.\(index)")
      }
    }
  }

  private var addAlternativeButton: some View {
    Button {
      model.addAlternative()
      tick += 1
    } label: {
      Label("Add another way to make this hand", systemImage: "arrow.triangle.branch")
        .frame(minHeight: 44)
    }
    .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
    .accessibilityIdentifier("guided.addWay")
  }

  private func groupRow(alternative: Int, index: Int, spec: GroupSpec) -> some View {
    let draft = GuidedGroupDraft(spec)
    let groupBinding = Binding<GuidedGroupDraft>(
      get: { draft },
      set: { newDraft in
        guard model.line.alternatives.indices.contains(alternative),
          model.line.alternatives[alternative].indices.contains(index)
        else { return }
        model.line.alternatives[alternative][index].tile = newDraft.tile
      })
    let countBinding = Binding<Int>(
      get: { spec.count },
      set: { value in
        guard model.line.alternatives.indices.contains(alternative),
          model.line.alternatives[alternative].indices.contains(index)
        else { return }
        model.line.alternatives[alternative][index].count = value
      })
    let isLast = index == model.line.alternatives[alternative].count - 1
    return VStack(alignment: .leading, spacing: Spacing.sm) {
      HStack {
        Text("Group \(index + 1)").font(Typography.body.weight(.semibold)).foregroundStyle(theme.text)
        Spacer()
        Button {
          model.moveGroup(index, by: -1, in: alternative)
        } label: {
          Image(systemName: "arrow.up").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(index == 0)
        .accessibilityLabel("Move group \(index + 1) up")
        .accessibilityIdentifier("guided.up.\(alternative).\(index)")
        Button {
          model.moveGroup(index, by: 1, in: alternative)
        } label: {
          Image(systemName: "arrow.down").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(isLast)
        .accessibilityLabel("Move group \(index + 1) down")
        .accessibilityIdentifier("guided.down.\(alternative).\(index)")
        Button(role: .destructive) {
          model.removeGroup(index, from: alternative)
        } label: {
          Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Remove group \(index + 1)")
        .accessibilityIdentifier("guided.remove.\(alternative).\(index)")
      }
      HStack {
        Text("Tile").font(Typography.small).foregroundStyle(theme.textMuted)
        Spacer(minLength: Spacing.sm)
        Picker("Tile type", selection: groupBinding.kind) {
          ForEach(GuidedKind.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .tint(theme.primary)
        .accessibilityIdentifier("guided.kind.\(alternative).\(index)")
      }
      switch draft.kind {
      case .number:
        pickerRow("Number") {
          Picker("Number", selection: groupBinding.number) {
            ForEach(1...9, id: \.self) { Text("\($0)").tag($0) }
          }
          .accessibilityIdentifier("guided.number.\(alternative).\(index)")
        }
        suitPicker(groupBinding, id: "guided.suit.\(alternative).\(index)")
      case .matchingDragon:
        suitPicker(groupBinding, id: "guided.suit.\(alternative).\(index)")
      case .wind:
        pickerRow("Wind") {
          Picker("Wind", selection: groupBinding.wind) {
            ForEach(Wind.allCases, id: \.self) { Text(Self.windName($0)).tag($0) }
          }
        }
      case .dragon:
        pickerRow("Which") {
          Picker("Dragon", selection: groupBinding.dragon) {
            Text("Red Dragon").tag(Dragon.red)
            Text("Green Dragon").tag(Dragon.green)
            Text("Soap (White Dragon, or the 0 in a year)").tag(Dragon.white)
          }
        }
      case .flower:
        EmptyView()
      }
      StepperField("Tiles in this group", value: countBinding, step: 1, range: 1...8, unit: "")
      Text(Self.describe(spec))
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("guided.group.\(alternative).\(index)")
  }

  private func pickerRow<P: View>(_ title: String, @ViewBuilder _ picker: () -> P) -> some View {
    HStack {
      Text(title).font(Typography.small).foregroundStyle(theme.textMuted)
      Spacer(minLength: Spacing.sm)
      picker().tint(theme.primary)
    }
  }

  private func suitPicker(_ draft: Binding<GuidedGroupDraft>, id: String) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      pickerRow("Suit") {
        Picker("Suit", selection: draft.suit) {
          ForEach(GuidedSuit.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .accessibilityIdentifier(id)
      }
      Text("A, B and C are three different suits, for example Cracks, Bams and Dots. Use the same letter to keep the same suit.")
        .font(Typography.small)
        .foregroundStyle(theme.textFaint)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  static func windName(_ wind: Wind) -> String {
    switch wind {
    case .north: return "North"
    case .east: return "East"
    case .west: return "West"
    case .south: return "South"
    }
  }

  private static func describe(_ spec: GroupSpec) -> String {
    GuidedLine.notation(of: spec)
  }

  // MARK: Preview

  private var previewCard: some View {
    SectionCard("Preview") {
      switch model.validation {
      case .invalid(let problems):
        VStack(alignment: .leading, spacing: Spacing.sm) {
          ForEach(Array(problems.prefix(3).enumerated()), id: \.offset) { entry in
            Label {
              Text(entry.element).font(Typography.small).foregroundStyle(theme.textMuted)
            } icon: {
              Image(systemName: "info.circle").foregroundStyle(theme.textMuted)
            }
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided.problems")
      case .valid(let line, let targets):
        VStack(alignment: .leading, spacing: Spacing.md) {
          if let variant = line.variants.first {
            ResolvedPatternView(variant: variant, target: LineDetailModel(line: line).current, size: .small)
          }
          ForEach(Array(line.variants.enumerated()), id: \.offset) { entry in
            let text = Notation.describe(entry.element, shift: line.shift, concealed: line.concealed)
            Text(line.variants.count > 1 ? "Way \(entry.offset + 1): \(text)" : text)
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          Text("Written as: \(line.variants.map(\.source).joined(separator: " | "))")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(theme.textFaint)
          HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.success).accessibilityHidden(true)
            Text("14 tiles \u{2713} \u{00B7} \(targets == 1 ? "1 possible hand" : "\(targets) possible hands")")
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.success)
          }
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("editor.valid")
        }
      }
    }
  }

  // MARK: Details

  private var detailsCard: some View {
    SectionCard("Details") {
      HStack {
        Text("Section").font(Typography.body).foregroundStyle(theme.text)
        Spacer(minLength: Spacing.sm)
        Picker("Section", selection: $model.base.sectionChoice) {
          ForEach(model.base.availableSections, id: \.self) { Text($0).tag(SectionChoice.existing($0)) }
          Text("New section\u{2026}").tag(SectionChoice.new)
        }
        .pickerStyle(.menu)
        .tint(theme.primary)
        .accessibilityIdentifier("editor.section")
      }
      .frame(minHeight: 44)
      if model.base.sectionChoice == .new {
        TextField("Section name", text: $model.base.newSectionName)
          .textInputAutocapitalization(.words)
          .padding(Spacing.md)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .accessibilityIdentifier("editor.newSection")
        if let problem = model.base.sectionProblem {
          Text(problem).font(Typography.small).foregroundStyle(theme.danger)
        }
      }
      TextField("Name (optional)", text: $model.line.name)
        .focused($nameFocused)
        .textInputAutocapitalization(.words)
        .padding(Spacing.md)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityIdentifier("editor.name")
      StepperField("Points", value: $model.line.points, step: 5, range: LineEditorModel.pointsRange, unit: "pts")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Spacing.sm) {
          ForEach(LineEditorModel.quickPoints, id: \.self) { value in
            ChipView("\(value)", isSelected: model.line.points == value) { model.line.points = value }
          }
        }
      }
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text("Exposed or concealed").font(Typography.small).foregroundStyle(theme.textMuted)
        SegmentedPicker("Exposed or concealed", selection: $model.line.concealed, options: [false, true]) {
          $0 ? "Concealed" : "Exposed"
        }
        .accessibilityIdentifier("editor.exposure")
        Text(
          model.line.concealed
            ? "Concealed: you make the whole hand yourself, with no tiles taken from other players' discards (except to finish)."
            : "Exposed: you may take discarded tiles to make groups and show them on your rack."
        )
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      }
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text("Numbers can move").font(Typography.small).foregroundStyle(theme.textMuted)
        SegmentedPicker(
          "Numbers can move", selection: $model.line.shift, options: [Shift.none, Shift.consecutive, Shift.parity]
        ) { shift in
          switch shift {
          case .none: return "Fixed"
          case .consecutive: return "Together"
          case .parity: return "By two"
          }
        }
        .accessibilityIdentifier("editor.shift")
        Text(Self.shiftHelp(model.line.shift))
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private static func shiftHelp(_ shift: Shift) -> String {
    switch shift {
    case .none: return "The numbers stay exactly as you built them."
    case .consecutive:
      return "All the numbers move up or down together and keep the same gaps, for example 1 2 3 or 4 5 6."
    case .parity:
      return "All the numbers move together by two, so odd numbers stay odd and even numbers stay even."
    }
  }

  // MARK: Save

  private func save() {
    guard let line = model.validLine, let source = cards.record(id: cardID)?.text else { return }
    let text: String
    if let lineID {
      text = CardEditing.text(replacing: lineID, with: line, in: source)
    } else {
      text = CardEditing.text(adding: line, to: source)
    }
    cards.updateText(id: cardID, text: text)
    if !settings.settings.cardNoticeSeen { settings.update { $0.cardNoticeSeen = true } }
    onSaved()
    dismiss()
  }
}
