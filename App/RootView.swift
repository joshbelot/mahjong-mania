import SwiftUI

/// The five tabs. Each tab's root view lives in its feature folder and applies its own title and
/// `settingsToolbar()`.
struct RootView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @State fileprivate var selectedTab: AppTab
  @State fileprivate var cardsPath: [CardsRoute] = []
  @Environment(IncomingLinks.self) fileprivate var links
  @State fileprivate var importRequest: LinkImport?
  @State fileprivate var linkError: CardQRCode.DecodeError?
  @State fileprivate var openedCardID: String?
  @Environment(CardsStore.self) private var cards
  @State fileprivate var chooserRequest = false

  init(startTab: AppTab? = nil) {
    _selectedTab = State(initialValue: LaunchOptions.initialTab() ?? startTab ?? .game)
  }

  /// A card file that arrived by QR code, waiting in the Import screen.
  fileprivate struct LinkImport: Identifiable {
    let id = UUID()
    let text: String
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack { GameHomeView() }
        .tabItem { Label("Game", systemImage: "dice") }
        .accessibilityIdentifier("tab.game")
        .tag(AppTab.game)
      if HelperGate(settings.settings.assistLevel).showsHelperTab {
        NavigationStack { HelperView() }
          .tabItem { Label("Helper", systemImage: "lightbulb") }
          .accessibilityIdentifier("tab.helper")
          .tag(AppTab.helper)
      }
      NavigationStack { PracticeHomeView() }
        .tabItem { Label("Practice", systemImage: "flame.fill") }
        .accessibilityIdentifier("tab.practice")
        .tag(AppTab.practice)
      NavigationStack(path: $cardsPath) { CardsListView(openChooser: $chooserRequest) }
        .tabItem { Label("Cards", systemImage: "rectangle.stack") }
        .accessibilityIdentifier("tab.cards")
        .tag(AppTab.cards)
      NavigationStack { LearnHomeView() }
        .tabItem { Label("Learn", systemImage: "graduationcap") }
        .accessibilityIdentifier("tab.learn")
        .tag(AppTab.learn)
    }
    .tint(theme.primary)
    .safeAreaInset(edge: .top, spacing: 0) {
      if settings.settings.pendingCardSetup && selectedTab != .cards { cardSetupBanner }
    }
    .onChange(of: settings.settings.activeCardID) { clearSetupIfCardActivated() }
    .environment(\.tabSwitcher, TabSwitcher { selectedTab = $0 })
    .environment(\.cardsNavigator, CardsNavigator { cardsPath.append($0) })
    .onChange(of: links.pending, initial: true) { handlePendingLink() }
    .sheet(item: $importRequest, onDismiss: showImportedCard) { request in
      ImportView(initialText: request.text) { openedCardID = $0 }
    }
    .alert(
      "Can't open this QR code", isPresented: Binding(get: { linkError != nil }, set: { if !$0 { linkError = nil } })
    ) {
      Button("OK", role: .cancel) {}
        .accessibilityIdentifier("link.error.ok")
    } message: {
      Text(linkError?.message ?? "")
    }
    .onChange(of: settings.settings.assistLevel) {
      if selectedTab == .helper && !HelperGate(settings.settings.assistLevel).showsHelperTab {
        selectedTab = .game
      }
    }
  }
}

extension RootView {
  /// Nonblocking reminder after onboarding's "I'll enter my own card" (NEXT_WAVES §3.5).
  fileprivate var cardSetupBanner: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text("Set up your card")
        .font(Typography.body.weight(.semibold))
        .foregroundStyle(theme.text)
      Text("Build the hands from your own card to use them in Helper and Game.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      AdaptiveStack(spacing: Spacing.sm) {
        Button("Set up your card") {
          selectedTab = .cards
          cardsPath = []
          chooserRequest = true
        }
        .buttonStyle(PrimaryButton(.primary, fullWidth: true))
        .accessibilityIdentifier("cardsetup.start")
        Button("Use the Practice Card for now") {
          settings.update {
            $0.pendingCardSetup = false
            $0.activeCardID = AppSettings.practiceCardID
          }
        }
        .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
        .accessibilityIdentifier("cardsetup.practice")
      }
    }
    .padding(Spacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.primarySoft)
    // A pinned banner must not take over the screen at accessibility text sizes; the full setup lives in Cards.
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("cardsetup.banner")
  }

  /// Activating a card with at least one hand completes setup. An empty card never does.
  fileprivate func clearSetupIfCardActivated() {
    let id = settings.settings.activeCardID
    guard settings.settings.pendingCardSetup, id != AppSettings.practiceCardID,
      let card = cards.card(id: id), !card.lines.isEmpty
    else { return }
    settings.update { $0.pendingCardSetup = false }
  }

  /// Opens the Import screen, pre-filled, for a card link; says so if the link is not a card.
  fileprivate func handlePendingLink() {
    guard let url = links.pending else { return }
    links.pending = nil
    do {
      importRequest = LinkImport(text: try CardQRCode.cardText(from: url))
    } catch let error as CardQRCode.DecodeError {
      linkError = error
    } catch {
      linkError = .notACard
    }
  }

  /// After a QR import, show the new card in the Cards tab.
  fileprivate func showImportedCard() {
    guard let id = openedCardID else { return }
    openedCardID = nil
    selectedTab = .cards
    cardsPath = [.card(id)]
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return RootView()
    .environment(stores.settings)
    .environment(stores.cards)
    .environment(stores.practice)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return RootView()
    .environment(stores.settings)
    .environment(stores.cards)
    .environment(stores.practice)
    .preferredColorScheme(.dark)
}
