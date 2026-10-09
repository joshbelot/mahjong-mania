import MahjongCore
import SwiftUI

/// What the line-editor sheet was asked to do.
enum LineEditorRequest: Identifiable, Hashable {
  case new
  case edit(String)

  var id: String {
    switch self {
    case .new: return "new"
    case .edit(let lineID): return "edit-\(lineID)"
    }
  }

  var lineID: String? {
    if case .edit(let id) = self { return id }
    return nil
  }
}

/// Presents `LineEditorView` in its own navigation stack for `request` on card `cardID`.
struct LineEditorSheet: View {
  let cardID: String
  let request: LineEditorRequest
  var onSaved: () -> Void = {}

  @Environment(CardsStore.self) private var cards

  var body: some View {
    NavigationStack {
      if let card = cards.card(id: cardID) {
        LineEditorView(cardID: cardID, lineID: request.lineID, model: model(for: card), onSaved: onSaved)
      } else {
        EmptyStateView("Card not found", systemImage: "rectangle.stack.badge.minus")
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private func model(for card: Card) -> LineEditorModel {
    if let lineID = request.lineID, let line = card.lines.first(where: { $0.id == lineID }) {
      return LineEditorModel(card: card, editing: line)
    }
    return LineEditorModel(availableSections: card.sections)
  }
}

/// Sections and lines of one card, with search (SPEC §11.7).
struct CardDetailView: View {
  let cardID: String

  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CardsStore.self) private var cards
  @Environment(SettingsStore.self) private var settings
  @Environment(\.cardsNavigator) private var navigator

  @State private var query = ""
  @State private var editorRequest: LineEditorRequest?
  @State private var lineToDelete: CardLine?
  @State private var showRename = false
  @State private var renameText = ""
  @State private var showDeleteCard = false
  @State private var savedTick = 0

  var body: some View {
    Group {
      if let card = cards.card(id: cardID) {
        content(card)
      } else {
        EmptyStateView("Card not found", systemImage: "rectangle.stack.badge.minus")
      }
    }
    .background(theme.bg)
    .sheet(item: $editorRequest) { request in
      LineEditorSheet(cardID: cardID, request: request) { savedTick += 1 }
    }
    .sensoryFeedback(.success, trigger: savedTick)
  }

  // MARK: Content

  private func content(_ card: Card) -> some View {
    let hasLines = !card.lines.isEmpty
    return List {
      ForEach(card.sections, id: \.self) { section in
        let rows = filteredLines(in: card, section: section)
        if !rows.isEmpty {
          Section(section) {
            ForEach(rows, id: \.line.id) { row in
              lineRow(card: card, line: row.line, index: row.index)
            }
          }
        }
      }
      if !card.builtIn && hasLines {
        Section {
          Button {
            editorRequest = .new
          } label: {
            Label("Add hand", systemImage: "plus.circle.fill")
              .font(Typography.body.weight(.semibold))
              .foregroundStyle(theme.primary)
              .frame(minHeight: 44, alignment: .leading)
          }
          .accessibilityIdentifier("card.addHand.row")
        }
        .listRowBackground(theme.surface)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.bg)
    .overlay {
      if !hasLines && !card.builtIn {
        EmptyStateView(
          "No hands yet", systemImage: "rectangle.stack.badge.plus",
          message: "Add the hands from your card one at a time, or import them from a card file.",
          actionTitle: "Add hand"
        ) {
          editorRequest = .new
        }
      } else if hasLines && !query.isEmpty && filteredCount(in: card) == 0 {
        ContentUnavailableView.search(text: query)
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if card.builtIn { builtInBanner(card) }
    }
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search hands")
    .navigationTitle(card.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !card.builtIn {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            editorRequest = .new
          } label: {
            Label("Add hand", systemImage: "plus")
          }
          .accessibilityIdentifier("card.addHand")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        optionsMenu(card)
      }
    }
    .alert("Rename card", isPresented: $showRename) {
      TextField("Card name", text: $renameText)
      Button("Save") { cards.rename(id: card.id, to: renameText) }
        .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete \u{201C}\(card.name)\u{201D}?", isPresented: $showDeleteCard, titleVisibility: .visible
    ) {
      Button("Delete card", role: .destructive) { deleteCard(card) }
    } message: {
      Text("This removes the card and its \(card.lines.count) hands. It can't be undone.")
    }
    .confirmationDialog(
      "Delete this hand?", isPresented: lineDeleteBinding, titleVisibility: .visible, presenting: lineToDelete
    ) { line in
      Button("Delete hand", role: .destructive) {
        cards.updateText(id: card.id, text: CardEditing.text(removing: line.id, from: card))
      }
    } message: { line in
      Text(line.displayName)
    }
  }

  private var lineDeleteBinding: Binding<Bool> {
    Binding(get: { lineToDelete != nil }, set: { if !$0 { lineToDelete = nil } })
  }

  private func builtInBanner(_ card: Card) -> some View {
    HStack(spacing: Spacing.md) {
      Image(systemName: "lock.fill")
        .foregroundStyle(theme.primary)
        .accessibilityHidden(true)
      Text("Built-in card \u{00B7} Duplicate to edit")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button("Duplicate") { duplicate(card) }
        .buttonStyle(PrimaryButton(.primary))
        .accessibilityIdentifier("card.duplicate")
    }
    .padding(.horizontal, Spacing.lg)
    .padding(.vertical, Spacing.sm)
    .background(theme.primarySoft)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("card.builtInBanner")
  }

  private func optionsMenu(_ card: Card) -> some View {
    Menu {
      Button {
        settings.update { $0.activeCardID = card.id }
      } label: {
        Label(
          isActive(card) ? "Active card" : "Set as active card",
          systemImage: isActive(card) ? "checkmark.circle.fill" : "checkmark.circle")
      }
      .disabled(isActive(card))
      Button {
        duplicate(card)
      } label: {
        Label("Duplicate", systemImage: "plus.square.on.square")
      }
      if !card.builtIn {
        Button {
          renameText = card.name
          showRename = true
        } label: {
          Label("Rename", systemImage: "pencil")
        }
      }
      ShareLink(item: Notation.serialize(card), subject: Text(card.name)) {
        Label("Share card", systemImage: "square.and.arrow.up")
      }
      if !card.builtIn {
        Button(role: .destructive) {
          showDeleteCard = true
        } label: {
          Label("Delete card", systemImage: "trash")
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .accessibilityLabel("Card options")
    .accessibilityIdentifier("card.menu")
  }

  // MARK: Rows

  private func lineRow(card: Card, line: CardLine, index: Int) -> some View {
    NavigationLink(value: CardsRoute.line(cardID: card.id, lineID: line.id)) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(spacing: Spacing.sm) {
          Text(line.displayName)
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.text)
          Spacer(minLength: Spacing.sm)
          Text("\(line.points) pts")
            .font(Typography.small.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(theme.textMuted)
          BadgeView(line.concealed ? .concealed : .exposed)
        }
        if let variant = line.variants.first {
          HandPatternView(variant: variant, line: line)
        }
        if line.variants.count > 1 {
          Text("+ \(line.variants.count - 1) more \(line.variants.count == 2 ? "way" : "ways")")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
      }
      .padding(.vertical, Spacing.xs)
    }
    .listRowBackground(theme.surface)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !card.builtIn {
        Button(role: .destructive) {
          lineToDelete = line
        } label: {
          Label("Delete", systemImage: "trash")
        }
        Button {
          editorRequest = .edit(line.id)
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .tint(theme.primary)
      }
    }
    .accessibilityIdentifier("line.row.\(index)")
  }

  // MARK: Helpers

  private struct IndexedLine {
    var index: Int
    var line: CardLine
  }

  private func filteredLines(in card: Card, section: String) -> [IndexedLine] {
    let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
    return card.lines.enumerated().compactMap { entry in
      let line = entry.element
      guard line.section == section else { return nil }
      if !needle.isEmpty {
        let haystack = (line.displayName + " " + line.section).lowercased()
        guard haystack.contains(needle) else { return nil }
      }
      return IndexedLine(index: entry.offset, line: line)
    }
  }

  private func filteredCount(in card: Card) -> Int {
    card.sections.reduce(0) { $0 + filteredLines(in: card, section: $1).count }
  }

  private func isActive(_ card: Card) -> Bool {
    settings.settings.activeCardID == card.id
  }

  private func duplicate(_ card: Card) {
    if let record = cards.duplicate(cardID: card.id) { navigator.push(.card(record.id)) }
  }

  private func deleteCard(_ card: Card) {
    if settings.settings.activeCardID == card.id {
      settings.update { $0.activeCardID = AppSettings.practiceCardID }
    }
    cards.delete(id: card.id)
    dismiss()
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { CardDetailView(cardID: PracticeCard.card.id) }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .environment(stores.sessions)
    .environment(stores.helper)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { CardDetailView(cardID: PracticeCard.card.id) }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .environment(stores.sessions)
    .environment(stores.helper)
    .preferredColorScheme(.dark)
}
