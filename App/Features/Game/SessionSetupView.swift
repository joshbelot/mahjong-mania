import MahjongCore
import SwiftUI

/// Pick 3-4 players, seat order and East, card, rules and money, then start the game night.
struct SessionSetupView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  @Environment(CardsStore.self) private var cards
  let onStart: (String) -> Void

  /// Selected player ids; the order is the seat order.
  @State private var selected: [String] = []
  @State private var eastID: String?
  @State private var cardID: String?
  @State private var rules = RuleSet.standard
  @State private var seeded = false
  @State private var showAdd = false
  @State private var newName = ""
  @State private var newColor: Int?
  @FocusState private var nameFocused: Bool

  private var canStart: Bool { (3...4).contains(selected.count) }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        playersCard
        if !selected.isEmpty { seatsCard }
        cardCard
        rulesCard
        moneyCard
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { startBar }
    .navigationTitle("New game night")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: seed)
  }

  // MARK: Cards

  private var playersCard: some View {
    SectionCard("Players") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        if players.activePlayers.isEmpty {
          Text("Add the people at your table. You need three or four.")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        } else {
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(players.activePlayers) { player in
              ChipView(
                player.name, isSelected: selected.contains(player.id),
                tint: PlayerPalette.color(at: player.colorIndex)
              ) { toggle(player.id) }
              .accessibilityIdentifier("setup.player.\(player.name)")
            }
          }
          Text(selectionHint)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
        addPlayer
      }
    }
  }

  private var selectionHint: String {
    switch selected.count {
    case 0, 1, 2: return "Pick 3 or 4 players. The order you tap is the seat order."
    case 3: return "3 players. You can add one more."
    default: return "4 players."
    }
  }

  @ViewBuilder
  private var addPlayer: some View {
    if showAdd {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(spacing: Spacing.sm) {
          TextField("Player name", text: $newName)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($nameFocused)
            .onSubmit(addNewPlayer)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
            .accessibilityIdentifier("setup.newName")
          Button("Add", action: addNewPlayer)
            .buttonStyle(PrimaryButton(.primary))
            .disabled(trimmedNewName.isEmpty)
            .accessibilityIdentifier("setup.addPlayer")
        }
        FlowLayout(spacing: 0, lineSpacing: 0) {
          ForEach(0..<PlayerPalette.hexes.count, id: \.self) { index in
            Button {
              newColor = index
            } label: {
              Circle()
                .fill(PlayerPalette.color(at: index))
                .frame(width: 30, height: 30)
                .overlay(
                  Circle().strokeBorder(theme.text, lineWidth: index == effectiveNewColor ? 3 : 0)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Colour \(index + 1)")
            .accessibilityAddTraits(index == effectiveNewColor ? .isSelected : [])
          }
        }
      }
    } else {
      Button {
        showAdd = true
        nameFocused = true
      } label: {
        Label("Add player", systemImage: "plus")
      }
      .buttonStyle(PrimaryButton(.ghost))
      .accessibilityIdentifier("setup.addPlayerToggle")
    }
  }

  private var seatsCard: some View {
    SectionCard("Seats") {
      VStack(alignment: .leading, spacing: 0) {
        let entries = Array(selected.enumerated())
        ForEach(entries, id: \.element) { entry in
          seatRow(index: entry.offset, id: entry.element)
          if entry.offset < entries.count - 1 { Divider().overlay(theme.border) }
        }
        Text("Seat order is play order around the table. East deals first.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .padding(.top, Spacing.md)
      }
    }
  }

  private func seatRow(index: Int, id: String) -> some View {
    let name = players.name(of: id)
    return HStack(spacing: Spacing.md) {
      Text("\(index + 1)")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.textMuted)
        .frame(width: 16)
        .accessibilityHidden(true)
      AvatarView(name: name, colorIndex: players.colorIndex(of: id), size: 36)
      VStack(alignment: .leading, spacing: 0) {
        Text(name)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
          .lineLimit(1)
        if id == effectiveEastID {
          BadgeView(.east)
        } else {
          Button {
            eastID = id
          } label: {
            Text("Make East")
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.primary)
              .frame(minHeight: 44, alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("setup.east.\(name)")
        }
      }
      Spacer(minLength: Spacing.sm)
      moveButton("arrow.up", label: "Move \(name) up", enabled: index > 0) { move(index, by: -1) }
      moveButton("arrow.down", label: "Move \(name) down", enabled: index < selected.count - 1) {
        move(index, by: 1)
      }
    }
    .frame(minHeight: 56)
  }

  private func moveButton(
    _ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(enabled ? theme.primary : theme.textFaint)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private var cardCard: some View {
    SectionCard("Card") {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack {
          Text("Hand names and points")
            .font(Typography.body)
            .foregroundStyle(theme.text)
          Spacer(minLength: Spacing.sm)
          Picker("Card", selection: $cardID) {
            Text("None").tag(String?.none)
            ForEach(cards.cards) { card in
              Text(card.name).tag(Optional(card.id))
            }
          }
          .pickerStyle(.menu)
          .tint(theme.primary)
          .accessibilityIdentifier("setup.card")
        }
        Text("Pick a card to choose hands by name when you record them. None is fine too.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
    }
  }

  private var rulesCard: some View {
    SectionCard("Rules") {
      NavigationLink {
        RulesEditorView(rules: $rules)
      } label: {
        ListRowView(RulesSummary.title(rules), subtitle: RulesSummary.text(rules)) {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.textFaint)
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("setup.rules")
    }
  }

  private var moneyCard: some View {
    SectionCard("Money") {
      VStack(spacing: 0) {
        GameToggleRow(
          title: "Play for money", subtitle: "Settle up at the end of the night.",
          isOn: $rules.money.enabled, identifier: "setup.money")
        if rules.money.enabled {
          Divider().overlay(theme.border)
          StepperField("Cents per point", value: $rules.money.centsPerPoint, range: 1...100, unit: "\u{00A2}")
          Text("A 25-point hand is worth \(Scoring.formatMoney(cents: 25 * rules.money.centsPerPoint, symbol: rules.money.currencySymbol)).")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.sm)
        }
      }
    }
  }

  private var startBar: some View {
    VStack(spacing: Spacing.xs) {
      if sessions.activeSession != nil {
        Text("Starting a new game night ends the one in progress.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
      Button("Start game night", action: start)
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .disabled(!canStart)
        .accessibilityIdentifier("setup.start")
    }
    .padding(.horizontal, Spacing.lg)
    .padding(.vertical, Spacing.md)
    .frame(maxWidth: .infinity)
    .background(theme.bg)
    .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
  }

  // MARK: Logic

  private var trimmedNewName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// The seat that deals first: the chosen player, else the first seat.
  private var effectiveEastID: String? {
    if let eastID, selected.contains(eastID) { return eastID }
    return selected.first
  }

  /// The colour the next new player gets when none is chosen (same rule as `PlayersStore.add`).
  private var effectiveNewColor: Int {
    if let newColor { return newColor }
    let used = Set(players.activePlayers.map(\.colorIndex))
    let count = PlayerPalette.hexes.count
    return (0..<count).first { !used.contains($0) } ?? (players.players.count % count)
  }

  private func seed() {
    guard !seeded else { return }
    seeded = true
    rules = settings.settings.defaultRules
    let preferred = settings.settings.activeCardID
    cardID = cards.card(id: preferred) != nil ? preferred : nil
  }

  private func toggle(_ id: String) {
    if let index = selected.firstIndex(of: id) {
      selected.remove(at: index)
    } else if selected.count < 4 {
      selected.append(id)
    }
  }

  private func move(_ index: Int, by delta: Int) {
    let target = index + delta
    guard selected.indices.contains(index), selected.indices.contains(target) else { return }
    withAnimation(.snappy(duration: 0.2)) { selected.swapAt(index, target) }
  }

  private func addNewPlayer() {
    let name = trimmedNewName
    guard !name.isEmpty else { return }
    let player = players.add(name: name)
    if let newColor { players.setColor(id: player.id, index: newColor) }
    if selected.count < 4 { selected.append(player.id) }
    newName = ""
    newColor = nil
    nameFocused = false
  }

  private func start() {
    guard canStart else { return }
    let east = effectiveEastID.flatMap { selected.firstIndex(of: $0) } ?? 0
    let session = sessions.start(
      seatIDs: selected, startDealerIndex: east, cardID: cardID, rules: rules)
    onStart(session.id)
  }
}

#if DEBUG
  #Preview("Light") {
    NavigationStack { SessionSetupView { _ in } }
      .gameStores(GameSamples.stores().stores)
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    NavigationStack { SessionSetupView { _ in } }
      .gameStores(GameSamples.stores().stores)
      .preferredColorScheme(.dark)
  }
#endif
