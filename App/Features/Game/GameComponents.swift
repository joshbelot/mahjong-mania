import MahjongCore
import SwiftUI

extension PlayersStore {
  func name(of id: String) -> String { player(id: id)?.name ?? "Player" }

  func colorIndex(of id: String) -> Int { player(id: id)?.colorIndex ?? 0 }

  /// Player id → name for the given ids (including archived players).
  func nameMap(for ids: [String]) -> [String: String] {
    Dictionary(ids.map { ($0, name(of: $0)) }, uniquingKeysWith: { first, _ in first })
  }
}

/// A big selectable player pill with the avatar, for "Who won?" style choices.
struct PlayerChipView: View {
  @Environment(\.theme) private var theme
  let name: String
  let colorIndex: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Spacing.sm) {
        AvatarView(name: name, colorIndex: colorIndex, size: 32)
        Text(name)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(isSelected ? theme.onPrimary : theme.text)
          .lineLimit(1)
      }
      .padding(.leading, Spacing.sm)
      .padding(.trailing, Spacing.lg)
      .frame(minHeight: 48)
      .background(isSelected ? theme.primary : theme.surface, in: Capsule())
      .overlay(
        Capsule().strokeBorder(isSelected ? theme.primary : theme.border, lineWidth: isSelected ? 2 : 1)
      )
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(name)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// A title (and optional note) with the switch on the right, so UI tests can tap the switch itself.
struct GameToggleRow: View {
  @Environment(\.theme) private var theme
  let title: String
  var subtitle: String?
  @Binding var isOn: Bool
  var identifier = ""
  var isDisabled = false

  var body: some View {
    HStack(spacing: Spacing.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Typography.body)
          .foregroundStyle(theme.text)
        if let subtitle {
          Text(subtitle)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
      }
      Spacer(minLength: Spacing.sm)
      Toggle(title, isOn: $isOn)
        .labelsHidden()
        .tint(theme.primary)
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }
    .frame(minHeight: 44)
  }
}

/// Large signed points for the scoreboard rows. The accessibility label is "plus 100 points" etc.
struct ScorePointsText: View {
  @Environment(\.theme) private var theme
  let points: Int

  var body: some View {
    Text(PointsText.format(points))
      .font(.system(.title, design: .rounded, weight: .bold))
      .monospacedDigit()
      .foregroundStyle(color)
      .accessibilityLabel(spoken)
  }

  private var color: Color {
    if points > 0 { return theme.success }
    if points < 0 { return theme.danger }
    return theme.textMuted
  }

  private var spoken: String {
    if points > 0 { return "plus \(points) points" }
    if points < 0 { return "minus \(-points) points" }
    return "0 points"
  }
}

/// Overlapping avatars for a session's seats.
struct GameAvatarRow: View {
  @Environment(PlayersStore.self) private var players
  let ids: [String]
  var size: CGFloat = 28

  var body: some View {
    HStack(spacing: -size * 0.25) {
      ForEach(ids, id: \.self) { id in
        AvatarView(name: players.name(of: id), colorIndex: players.colorIndex(of: id), size: size)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(ids.map { players.name(of: $0) }.joined(separator: ", "))
  }
}

extension View {
  /// Injects the stores the Game screens read (previews and tests).
  func gameStores(_ stores: AppStores) -> some View {
    self
      .environment(stores.settings)
      .environment(stores.players)
      .environment(stores.sessions)
      .environment(stores.cards)
      .environment(stores)
  }
}

#if DEBUG
  /// Sample data for previews.
  @MainActor
  enum GameSamples {
    static func stores(ended: Bool = false) -> (stores: AppStores, sessionID: String) {
      let stores = AppStores.inMemory()
      let ids = ["Alex", "Bea", "Cy", "Dee"].map { stores.players.add(name: $0).id }
      var rules = RuleSet.standard
      rules.money = MoneySettings(enabled: true, centsPerPoint: 1, currencySymbol: "$")
      let session = stores.sessions.start(seatIDs: ids, cardID: PracticeCard.card.id, rules: rules)
      let line = PracticeCard.card.lines.first
      stores.sessions.addHand(
        .mahjong(
          MahjongInput(
            winnerID: ids[0], discarderID: ids[1], cardID: PracticeCard.card.id, lineID: line?.id,
            lineLabel: line?.displayName, basePoints: line?.points ?? 25)),
        to: session.id)
      stores.sessions.addHand(
        .mahjong(MahjongInput(winnerID: ids[1], basePoints: 30, jokerless: true)), to: session.id)
      stores.sessions.addHand(.wall(note: nil), to: session.id)
      stores.sessions.addHand(
        .adjustment(fromID: ids[3], toID: ids[0], points: 10, note: "Late"), to: session.id)
      if ended { stores.sessions.end(sessionID: session.id) }
      return (stores, session.id)
    }
  }
#endif

extension Date {
  /// "Oct 8"
  var gameShortDate: String { formatted(.dateTime.month(.abbreviated).day()) }
  /// "Oct 8, 2026"
  var gameFullDate: String { formatted(.dateTime.month(.abbreviated).day().year()) }
}
