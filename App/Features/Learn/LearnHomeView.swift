import SwiftUI

/// Where a row of the Learn home goes.
enum LearnRoute: Hashable {
  case topic(String)
  case houseRules
  case glossary
}

/// Root of the Learn tab: reading topics and the glossary, with a pointer to Practice.
struct LearnHomeView: View {
  @Environment(SettingsStore.self) private var settings
  @Environment(\.tabSwitcher) private var tabSwitcher
  @State private var showTiles = false

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        CoachTipBanner(screen: "learn.home")
        SectionCard("Read") {
          VStack(spacing: 0) {
            Button {
              showTiles = true
            } label: {
              LearnRow(
                symbol: "rectangle.grid.3x2", title: "Tiles cheat sheet",
                subtitle: "Every tile, what it is called and how many there are. Also in Practice and the Helper.")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learn.tiles.cheat")
            Divider()
            ForEach(LearnContent.topics) { topic in
              NavigationLink(value: LearnRoute.topic(topic.id)) {
                LearnRow(symbol: topic.symbol, title: topic.title, subtitle: topic.summary)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("learn.topic.\(topic.id)")
              Divider()
            }
            NavigationLink(value: LearnRoute.houseRules) {
              LearnRow(
                symbol: "list.bullet.rectangle", title: "House rules explained",
                subtitle: "Every rule in your rule book in plain words, and which ones are on.")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learn.topic.houserules")
            Divider()
            NavigationLink(value: LearnRoute.glossary) {
              LearnRow(
                symbol: "character.book.closed", title: "Glossary",
                subtitle: "Every term you will hear at the table, searchable.")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learn.glossary")
          }
        }
        SectionCard("Practise") {
          Button {
            tabSwitcher.select(.practice)
          } label: {
            LearnRow(
              symbol: "flame.fill", title: "Practise this in the Practice tab",
              subtitle: "Short lessons, a daily deal and the Pick-a-Hand and Charleston drills.")
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("learn.practice")
        }
      }
    }
    .sheet(isPresented: $showTiles) { TileCheatSheetView() }
    .navigationTitle("Learn")
    .settingsToolbar()
    .navigationDestination(for: LearnRoute.self) { route in
      switch route {
      case .topic(let id):
        if let topic = LearnContent.topic(id: id) { LearnTopicView(topic: topic) }
      case .houseRules:
        LearnTopicView(topic: LearnHouseRules.topic(for: settings.settings.defaultRules))
      case .glossary:
        GlossaryView()
      }
    }
  }
}

private struct LearnRow: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let symbol: String
  let title: String
  let subtitle: String
  var badge: String?

  var body: some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      if !typeSize.isAccessibilitySize {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(theme.primary)
          .frame(width: 32, height: 32)
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.leading)
        Text(subtitle)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        if let badge {
          Text(badge)
            .tinyStyle()
            .foregroundStyle(theme.gold)
            .padding(.top, 2)
        }
      }
      Spacer(minLength: Spacing.sm)
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(theme.textFaint)
        .padding(.top, Spacing.sm)
        .accessibilityHidden(true)
    }
    .padding(.vertical, Spacing.md)
    .frame(minHeight: 44)
    .contentShape(Rectangle())
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { LearnHomeView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .environment(TipCenter(seed: 1))
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { LearnHomeView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .environment(TipCenter(seed: 1))
    .preferredColorScheme(.dark)
}
