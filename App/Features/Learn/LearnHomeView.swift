import SwiftUI

/// Where a row of the Learn home goes.
enum LearnRoute: Hashable {
  case topic(String)
  case glossary
  case pickAHand
  case charleston
}

/// Root of the Learn tab: reading topics, the glossary and the two drills.
struct LearnHomeView: View {
  @Environment(SettingsStore.self) private var settings

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        CoachTipBanner(screen: "learn.home")
        SectionCard("Read") {
          VStack(spacing: 0) {
            ForEach(LearnContent.topics) { topic in
              NavigationLink(value: LearnRoute.topic(topic.id)) {
                LearnRow(symbol: topic.symbol, title: topic.title, subtitle: topic.summary)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("learn.topic.\(topic.id)")
              Divider()
            }
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
          VStack(spacing: 0) {
            NavigationLink(value: LearnRoute.pickAHand) {
              LearnRow(
                symbol: "hand.point.up.left", title: "Pick-a-Hand",
                subtitle: "Look at 13 tiles and choose the line you would aim for.",
                badge: "Best streak \(settings.settings.bestStreaks.pickAHand)")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learn.drill.pick")
            Divider()
            NavigationLink(value: LearnRoute.charleston) {
              LearnRow(
                symbol: "arrow.left.arrow.right", title: "Charleston Pass",
                subtitle: "Choose the 3 tiles you would pass and compare with the engine.",
                badge: "Best streak \(settings.settings.bestStreaks.charleston)")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learn.drill.charleston")
          }
        }
      }
    }
    .navigationTitle("Learn")
    .settingsToolbar()
    .navigationDestination(for: LearnRoute.self) { route in
      switch route {
      case .topic(let id):
        if let topic = LearnContent.topic(id: id) { LearnTopicView(topic: topic) }
      case .glossary:
        GlossaryView()
      case .pickAHand:
        PickAHandDrillView()
      case .charleston:
        CharlestonDrillView()
      }
    }
  }
}

private struct LearnRow: View {
  @Environment(\.theme) private var theme
  let symbol: String
  let title: String
  let subtitle: String
  var badge: String?

  var body: some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(theme.primary)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
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
