import MahjongCore
import SwiftUI

/// Records a Mahjong hand (or edits one when `handID` is set). One screen, no wizard: an experienced
/// player taps winner, Discard, thrower, a points chip and Save.
struct RecordHandView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(SettingsStore.self) private var settings
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  @Environment(CardsStore.self) private var cards
  let sessionID: String
  let handID: String?
  let onSaved: (String) -> Void

  @State private var draft = RecordHandDraft()
  @State private var loaded = false
  @State private var showLinePicker = false
  @State private var showNote = false

  var body: some View {
    NavigationStack {
      Group {
        if let session = sessions.session(id: sessionID) {
          form(session)
        } else {
          EmptyStateView("Game night not found", systemImage: "questionmark.folder")
        }
      }
      .background(theme.bg)
      .navigationTitle(handID == nil ? "Record a hand" : "Edit hand")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("record.cancel")
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .onAppear(perform: load)
  }

  // MARK: Form

  @ViewBuilder
  private func form(_ session: Session) -> some View {
    let card = session.cardID.flatMap { cards.card(id: $0) }
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        winnerCard(session)
        howCard(session)
        handCard(card)
        jokerlessCard(session)
        noteCard
        previewCard(session)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { saveBar(session) }
    .sheet(isPresented: $showLinePicker) {
      if let card {
        HandPickerView(card: card, selectedLineID: draft.lineID) { line in
          draft.apply(line: line, cardID: card.id)
          if !draft.jokerlessEnabled(rules: session.rules) { draft.jokerless = false }
        }
      }
    }
  }

  private func winnerCard(_ session: Session) -> some View {
    SectionCard("Who won?") {
      FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
        ForEach(session.seatIDs, id: \.self) { id in
          let name = players.name(of: id)
          PlayerChipView(
            name: name, colorIndex: players.colorIndex(of: id), isSelected: draft.winnerID == id
          ) { draft.selectWinner(id) }
          .accessibilityIdentifier("record.winner.\(name)")
        }
      }
    }
  }

  private func howCard(_ session: Session) -> some View {
    SectionCard("How?") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
          ChipView("Self-pick", isSelected: draft.how == .selfPick) { draft.selectHow(.selfPick) }
            .accessibilityIdentifier("record.how.self")
          ChipView("Discard", isSelected: draft.how == .discard) { draft.selectHow(.discard) }
            .accessibilityIdentifier("record.how.discard")
        }
        if draft.how == .discard {
          Text("Who threw it?")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.textMuted)
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(session.seatIDs.filter { $0 != draft.winnerID }, id: \.self) { id in
              let name = players.name(of: id)
              PlayerChipView(
                name: name, colorIndex: players.colorIndex(of: id), isSelected: draft.discarderID == id
              ) { draft.discarderID = id }
              .accessibilityIdentifier("record.thrower.\(name)")
            }
          }
        }
      }
    }
  }

  private func handCard(_ card: Card?) -> some View {
    SectionCard("Hand") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        if let card {
          HStack(spacing: Spacing.sm) {
            Button {
              showLinePicker = true
            } label: {
              ListRowView(
                draft.lineLabel ?? "Choose hand",
                subtitle: draft.hasLine ? card.name : "From \(card.name)"
              ) {
                Image(systemName: "chevron.right")
                  .font(.footnote.weight(.semibold))
                  .foregroundStyle(theme.textFaint)
                  .accessibilityHidden(true)
              }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("record.chooseHand")
            if draft.hasLine {
              Button {
                draft.clearLine()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.title3)
                  .foregroundStyle(theme.textFaint)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Clear chosen hand")
              .accessibilityIdentifier("record.clearHand")
            }
          }
          Divider().overlay(theme.border)
        }
        Text("Points")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
          ForEach(RecordHandDraft.quickPoints, id: \.self) { value in
            ChipView("\(value)", isSelected: draft.points == value) { draft.points = value }
              .accessibilityIdentifier("record.points.\(value)")
          }
        }
        StepperField("Points", value: $draft.points, step: 5, range: RecordHandDraft.pointsRange, unit: "pts")
        if draft.isCustomValue, let base = draft.linePoints {
          Text("Custom value. The card says \(base).")
            .font(Typography.small)
            .foregroundStyle(theme.warning)
            .accessibilityIdentifier("record.custom")
        }
      }
    }
  }

  private func jokerlessCard(_ session: Session) -> some View {
    let enabled = draft.jokerlessEnabled(rules: session.rules)
    return SectionCard("Jokerless?") {
      GameToggleRow(
        title: "Jokerless",
        subtitle: enabled ? "No jokers were used in the hand." : RecordHandDraft.jokerlessNote,
        isOn: $draft.jokerless, identifier: "record.jokerless", isDisabled: !enabled)
    }
  }

  @ViewBuilder
  private var noteCard: some View {
    if showNote || !draft.note.isEmpty {
      SectionCard("Note") {
        TextField("Optional note", text: $draft.note, axis: .vertical)
          .lineLimit(1...3)
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .accessibilityIdentifier("record.note")
      }
    } else {
      Button {
        showNote = true
      } label: {
        Label("Add note", systemImage: "plus")
      }
      .buttonStyle(PrimaryButton(.ghost))
      .accessibilityIdentifier("record.addNote")
    }
  }

  @ViewBuilder
  private func previewCard(_ session: Session) -> some View {
    SectionCard("Payments") {
      if let input = draft.input(rules: session.rules) {
        let payments = Scoring.payments(for: .mahjong(input), seats: session.seatIDs, rules: session.rules)
        let names = players.nameMap(for: session.seatIDs)
        VStack(alignment: .leading, spacing: Spacing.sm) {
          ForEach(session.seatIDs, id: \.self) { id in
            let points = payments[id] ?? 0
            HStack(spacing: Spacing.md) {
              AvatarView(name: players.name(of: id), colorIndex: players.colorIndex(of: id), size: 28)
              Text(players.name(of: id))
                .font(Typography.body)
                .foregroundStyle(theme.text)
              Spacer(minLength: Spacing.sm)
              PointsText(points)
              if session.rules.money.enabled {
                MoneyText(
                  cents: points * session.rules.money.centsPerPoint,
                  symbol: session.rules.money.currencySymbol)
              }
            }
            .frame(minHeight: 36)
          }
          Text(
            PaymentExplanation.text(
              input: input, seats: session.seatIDs, payments: payments, rules: session.rules,
              names: names, coach: settings.settings.assistLevel == .coach)
          )
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("record.explanation")
        }
      } else {
        Text("Choose the winner, how it was won and the points to see who pays what.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
    }
  }

  private func saveBar(_ session: Session) -> some View {
    Button(handID == nil ? "Save" : "Save changes") { save(session) }
      .buttonStyle(PrimaryButton(.primary, size: .large))
      .disabled(draft.input(rules: session.rules) == nil)
      .accessibilityIdentifier("record.save")
      .padding(.horizontal, Spacing.lg)
      .padding(.vertical, Spacing.md)
      .frame(maxWidth: .infinity)
      .background(theme.bg)
      .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
  }

  // MARK: Actions

  private func load() {
    guard !loaded else { return }
    loaded = true
    guard let handID, let session = sessions.session(id: sessionID),
      let hand = session.hands.first(where: { $0.id == handID }),
      case .mahjong(let input) = hand.kind
    else { return }
    draft = RecordHandDraft(editing: input, card: input.cardID.flatMap { cards.card(id: $0) })
    if !draft.jokerlessEnabled(rules: session.rules) { draft.jokerless = false }
    showNote = !draft.note.isEmpty
  }

  private func save(_ session: Session) {
    guard let input = draft.input(rules: session.rules) else { return }
    if let handID {
      sessions.editHand(id: handID, to: .mahjong(input), in: sessionID)
    } else {
      sessions.addHand(.mahjong(input), to: sessionID)
    }
    onSaved(input.winnerID)
    dismiss()
  }
}

/// Searchable list of a card's lines, grouped by section, with the compact pattern and points.
struct HandPickerView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  let card: Card
  let selectedLineID: String?
  let onPick: (CardLine) -> Void
  @State private var query = ""

  private struct PickerSection: Identifiable {
    let name: String
    let lines: [CardLine]
    var id: String { name }
  }

  private var sections: [PickerSection] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return card.sections.compactMap { name in
      let lines = card.lines.filter { line in
        line.section == name
          && (needle.isEmpty || line.displayName.localizedCaseInsensitiveContains(needle)
            || line.section.localizedCaseInsensitiveContains(needle))
      }
      return lines.isEmpty ? nil : PickerSection(name: name, lines: lines)
    }
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(sections) { section in
          Section {
            ForEach(section.lines) { line in
              row(line)
            }
          } header: {
            Text(section.name).foregroundStyle(theme.textMuted)
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(theme.bg)
      .searchable(text: $query, prompt: "Search hands")
      .navigationTitle(card.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private func row(_ line: CardLine) -> some View {
    Button {
      onPick(line)
      dismiss()
    } label: {
      HStack(alignment: .top, spacing: Spacing.md) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
          Text(line.displayName)
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.text)
          if let variant = line.variants.first {
            HandPatternView(variant: variant, line: line)
          }
        }
        Spacer(minLength: Spacing.sm)
        VStack(alignment: .trailing, spacing: Spacing.xs) {
          Text("\(line.points)")
            .font(Typography.body.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(theme.text)
          BadgeView(line.concealed ? .concealed : .exposed)
        }
        if line.id == selectedLineID {
          Image(systemName: "checkmark")
            .foregroundStyle(theme.primary)
            .accessibilityLabel("Selected")
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(theme.surface)
    .accessibilityIdentifier("pick.line.\(line.displayName)")
  }
}

#if DEBUG
  #Preview("Light") {
    let sample = GameSamples.stores()
    return Color.clear.sheet(isPresented: .constant(true)) {
      RecordHandView(sessionID: sample.sessionID, handID: nil) { _ in }
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    let sample = GameSamples.stores()
    return Color.clear.sheet(isPresented: .constant(true)) {
      RecordHandView(sessionID: sample.sessionID, handID: nil) { _ in }
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.dark)
  }
#endif
