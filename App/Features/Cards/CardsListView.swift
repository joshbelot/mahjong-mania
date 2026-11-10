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

  @Binding var openChooser: Bool
  @State private var showChooser = false
  @State private var showImport = false
  @State private var showNew = false
  @State private var newName = ""
  @State private var renameID: String?
  @State private var qrCard: Card?
  @State private var renameText = ""
  @State private var deleteTarget: Card?
  /// Set by the import sheet; opened once the sheet has gone.
  @State private var pendingOpenID: String?

  init(openChooser: Binding<Bool> = .constant(false)) {
    _openChooser = openChooser
  }

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
    .onChange(of: openChooser, initial: true) {
      if openChooser {
        openChooser = false
        showChooser = true
      }
    }
    .sheet(isPresented: $showChooser) {
      CardMethodChooser(
        build: {
          showChooser = false
          newName = ""
          showNew = true
        },
        importText: {
          showChooser = false
          showImport = true
        },
        scanQR: {
          showChooser = false
          showImport = true
        })
    }
    .sheet(item: $qrCard) { CardQRSheet(card: $0) }
    .alert("New card", isPresented: $showNew) {
      TextField("Card name", text: $newName)
      Button("Create") { createCard() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Give your card a name. Next you can build its hands one at a time, no special notation needed.")
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
    AdaptiveStack(spacing: Spacing.md) {
      Button {
        showChooser = true
      } label: {
        Label("Add a card", systemImage: "plus")
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
    .padding(.horizontal, Spacing.xs)
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
      ShareLink(item: CardFileExport(card: card), subject: Text(card.name), preview: SharePreview(card.name)) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
      if !card.builtIn {
        Button {
          qrCard = card
        } label: {
          Label("Show QR code", systemImage: "qrcode")
        }
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

/// "Add a card": how do you want to get the hands in? Printed-card scanning is not offered (NEXT_WAVES §3.5).
private struct CardMethodChooser: View {
  @Environment(SettingsStore.self) private var settings
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  let build: () -> Void
  let importText: () -> Void
  let scanQR: () -> Void

  var body: some View {
    NavigationStack {
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.md) {
          Text("How do you want to add your card?")
            .font(Typography.body)
            .foregroundStyle(theme.textMuted)
          method(
            "Build hands", "Choose the tiles for each hand from your own card, step by step.", "square.grid.2x2",
            "method.build", build)
          method(
            "Import card text", "Paste or open a card file in Mahjong Mania's text format.",
            "square.and.arrow.down", "method.import", importText)
          method(
            "Read a shared QR code", "Use a QR code made by Mahjong Mania on another device. It does not read printed cards.",
            "qrcode.viewfinder", "method.qr", scanQR)
          if settings.settings.pendingCardSetup {
            Button("Use the Practice Card for now") {
              settings.update {
                $0.pendingCardSetup = false
                $0.activeCardID = AppSettings.practiceCardID
              }
              dismiss()
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("method.practice")
          }
        }
      }
      .navigationTitle("Add a card")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.accessibilityIdentifier("method.cancel")
        }
      }
    }
    .presentationDetents([.large])
  }

  private func method(
    _ title: String, _ detail: String, _ symbol: String, _ id: String, _ action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: Spacing.md) {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(theme.primary)
          .frame(width: 32)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Spacing.xs) {
          Text(title).font(Typography.h2).foregroundStyle(theme.text)
          Text(detail)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(Spacing.lg)
      .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border))
      .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(id)
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
