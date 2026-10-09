import MahjongCore
import SwiftUI

/// Where a push in the Cards tab goes.
enum CardsRoute: Hashable {
  case card(String)
  case line(cardID: String, lineID: String)
}

/// Root of the Cards tab: the Practice Card and the user's cards, with New and Import (SPEC §11.7).
struct CardsListView: View {
  @Environment(\.theme) private var theme
  @Environment(CardsStore.self) private var cards
  @Environment(SettingsStore.self) private var settings
  @Environment(\.cardsNavigator) private var navigator

  @State private var showImport = false
  @State private var showNew = false
  @State private var newName = ""
  @State private var renameID: String?
  @State private var renameText = ""
  @State private var deleteTarget: Card?
  /// Set by the import sheet; opened once the sheet has gone.
  @State private var pendingOpenID: String?

  var body: some View {
    List {
      Section {
        actionBar
          .listRowInsets(EdgeInsets(top: Spacing.sm, leading: 0, bottom: Spacing.sm, trailing: 0))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
      Section {
        ForEach(cards.cards) { card in
          row(card)
        }
      }
      .listRowBackground(theme.surface)
    }
    .scrollContentBackground(.hidden)
    .background(theme.bg)
    .navigationTitle("Cards")
    .settingsToolbar()
    .navigationDestination(for: CardsRoute.self) { route in
      switch route {
      case .card(let id):
        CardDetailView(cardID: id)
      case .line(let cardID, let lineID):
        LineDetailView(cardID: cardID, lineID: lineID)
      }
    }
    .sheet(isPresented: $showImport) {
      if let id = pendingOpenID {
        pendingOpenID = nil
        navigator.push(.card(id))
      }
    } content: {
      ImportView { pendingOpenID = $0 }
    }
    .alert("New card", isPresented: $showNew) {
      TextField("Card name", text: $newName)
      Button("Create") { createCard() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Give your card a name. You can add hands one by one or import them.")
    }
    .alert("Rename card", isPresented: renameBinding) {
      TextField("Card name", text: $renameText)
      Button("Save") {
        if let renameID, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          cards.rename(id: renameID, to: renameText)
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete this card?", isPresented: deleteBinding, titleVisibility: .visible, presenting: deleteTarget
    ) { card in
      Button("Delete \u{201C}\(card.name)\u{201D}", role: .destructive) { delete(card) }
    } message: { card in
      Text("This removes the card and its \(card.lines.count) hands. It can't be undone.")
    }
  }

  // MARK: Pieces

  private var actionBar: some View {
    HStack(spacing: Spacing.md) {
      Button {
        newName = ""
        showNew = true
      } label: {
        Label("New", systemImage: "plus")
      }
      .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
      .accessibilityIdentifier("cards.new")
      Button {
        showImport = true
      } label: {
        Label("Import", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
      .accessibilityIdentifier("cards.import")
    }
  }

  private func row(_ card: Card) -> some View {
    let active = settings.settings.activeCardID == card.id
    return NavigationLink(value: CardsRoute.card(card.id)) {
      ListRowView(card.name, subtitle: subtitle(card)) {
        HStack(spacing: Spacing.sm) {
          if card.builtIn { PillLabel("Built-in") }
          if active {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(theme.primary)
              .accessibilityLabel("Active card")
          }
        }
      }
    }
    .accessibilityIdentifier("cards.row.\(card.id)")
    .contextMenu {
      Button {
        settings.update { $0.activeCardID = card.id }
      } label: {
        Label("Set active", systemImage: "checkmark.circle")
      }
      .disabled(active)
      Button {
        if let record = cards.duplicate(cardID: card.id) { navigator.push(.card(record.id)) }
      } label: {
        Label("Duplicate", systemImage: "plus.square.on.square")
      }
      if !card.builtIn {
        Button {
          renameText = card.name
          renameID = card.id
        } label: {
          Label("Rename", systemImage: "pencil")
        }
      }
      ShareLink(item: Notation.serialize(card), subject: Text(card.name)) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
      if !card.builtIn {
        Button(role: .destructive) {
          deleteTarget = card
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }

  private func subtitle(_ card: Card) -> String {
    let count = card.lines.count == 1 ? "1 hand" : "\(card.lines.count) hands"
    if let year = card.year { return "\(count) \u{00B7} \(year)" }
    return count
  }

  // MARK: Actions

  private var renameBinding: Binding<Bool> {
    Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })
  }

  private var deleteBinding: Binding<Bool> {
    Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
  }

  private func createCard() {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    let record = cards.createCard(name: trimmed.isEmpty ? "My card" : trimmed)
    navigator.push(.card(record.id))
  }

  private func delete(_ card: Card) {
    if settings.settings.activeCardID == card.id {
      settings.update { $0.activeCardID = AppSettings.practiceCardID }
    }
    cards.delete(id: card.id)
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { CardsListView() }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { CardsListView() }
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .environment(stores.settings)
    .preferredColorScheme(.dark)
}
