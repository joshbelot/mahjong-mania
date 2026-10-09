import MahjongCore
import SwiftUI

/// First-launch flow: Welcome, "How much help do you want?", "Which card?". Three full-screen pages with
/// progress dots, Skip and Next. Choices are saved as they are made; finishing sets `onboardingDone`.
struct OnboardingView: View {
  enum CardChoice: String, CaseIterable, Sendable {
    case practice, own, later
  }

  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @State private var page = 0
  @State private var cardChoice = CardChoice.practice

  private static let pageCount = 3

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button("Skip") { finish() }
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.primary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, Spacing.lg)

        TabView(selection: $page) {
          welcomePage.tag(0)
          assistPage.tag(1)
          cardPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        VStack(spacing: Spacing.lg) {
          dots
          if page < Self.pageCount - 1 {
            Button("Next") {
              withAnimation(.smooth(duration: 0.25)) { page += 1 }
            }
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .accessibilityIdentifier("onboarding.next")
          } else {
            Button("Get started") { finish() }
              .buttonStyle(PrimaryButton(.primary, size: .large))
              .accessibilityIdentifier("onboarding.done")
          }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
      }
      .frame(maxWidth: 640)
    }
  }

  // MARK: Chrome

  private var dots: some View {
    HStack(spacing: Spacing.sm) {
      ForEach(0..<Self.pageCount, id: \.self) { index in
        Circle()
          .fill(index == page ? theme.primary : theme.border)
          .frame(width: 8, height: 8)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Page \(page + 1) of \(Self.pageCount)")
  }

  private func finish() {
    settings.update { $0.onboardingDone = true }
    settings.flush()
  }

  // MARK: Pages

  private func pageScroll<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Spacing.lg)
      .padding(.vertical, Spacing.lg)
    }
  }

  private static let welcomeTiles: [Tile] = ["5D", "R", "J", "F", "2B"].compactMap { Tile(code: $0) }

  private var welcomePage: some View {
    pageScroll {
      HStack(spacing: Spacing.sm) {
        ForEach(Array(Self.welcomeTiles.enumerated()), id: \.offset) { entry in
          TileView(tile: entry.element, size: .medium)
        }
      }
      .accessibilityHidden(true)
      .padding(.top, Spacing.lg)
      Text("Welcome to Mahjong Mania")
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      Text("A table-side companion for American Mahjong. It keeps score, and it helps only as much as you ask.")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: Spacing.md) {
        featureRow("dice", "Keep score at game night, with payouts worked out for you.")
        featureRow("lightbulb", "Get hints on your hand, only when you want them.")
        featureRow("graduationcap", "Learn the tiles, the card and the Charleston.")
      }
    }
  }

  private func featureRow(_ symbol: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(theme.primary)
        .frame(width: 32)
        .accessibilityHidden(true)
      Text(text)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var assistPage: some View {
    pageScroll {
      Text("How much help do you want?")
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, Spacing.lg)
      Text("You can change this any time in Settings.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      choiceCard(
        title: "Off", detail: "Just keep score. No hints and no tips.",
        example: "Nothing extra appears on screen.",
        selected: settings.settings.assistLevel == .off, id: "assist.off"
      ) { settings.update { $0.assistLevel = .off } }
      choiceCard(
        title: "Peek", detail: "Hints stay hidden until you ask for them.",
        example: "Tap \"Show closest hands\" to see your top 3.",
        selected: settings.settings.assistLevel == .peek, id: "assist.peek"
      ) { settings.update { $0.assistLevel = .peek } }
      choiceCard(
        title: "Coach", detail: "Hints and short explanations appear on their own.",
        example: "\"Pass these 3 tiles: nothing on your top hands uses them.\"",
        selected: settings.settings.assistLevel == .coach, id: "assist.coach"
      ) { settings.update { $0.assistLevel = .coach } }
    }
  }

  private var cardPage: some View {
    pageScroll {
      Text("Which card?")
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, Spacing.lg)
      Text("The hands you play for are printed on a card.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      choiceCard(
        title: "Use the Practice Card",
        detail: "An original card made for learning. Good for trying every feature right away.",
        example: nil, selected: cardChoice == .practice, id: "card.practice"
      ) { choose(.practice) }
      choiceCard(
        title: "I'll enter my own card",
        detail: "Type in the hands from your own copy of the card.",
        example: "After setup, open the Cards tab and tap New.",
        selected: cardChoice == .own, id: "card.own"
      ) { choose(.own) }
      choiceCard(
        title: "Decide later", detail: "Start with the Practice Card. You can switch in the Cards tab.",
        example: nil, selected: cardChoice == .later, id: "card.later"
      ) { choose(.later) }
    }
  }

  private func choose(_ choice: CardChoice) {
    cardChoice = choice
    // Every option starts on the Practice Card; an entered card is picked in the Cards tab.
    settings.update { $0.activeCardID = AppSettings.practiceCardID }
  }

  private func choiceCard(
    title: String, detail: String, example: String?, selected: Bool, id: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(alignment: .firstTextBaseline) {
          Text(title)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.leading)
          Spacer(minLength: Spacing.sm)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selected ? theme.primary : theme.textFaint)
            .accessibilityHidden(true)
        }
        Text(detail)
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        if let example {
          Text(example)
            .font(Typography.small)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(selected ? theme.primarySoft : theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.lg)
          .strokeBorder(selected ? theme.primary : theme.border, lineWidth: selected ? 2 : 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier(id)
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return OnboardingView()
    .environment(stores.settings)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return OnboardingView()
    .environment(stores.settings)
    .preferredColorScheme(.dark)
}
