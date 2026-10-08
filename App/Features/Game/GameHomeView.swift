import MahjongCore
import SwiftUI

/// Root of the Game tab: resume the game in progress, start a new one, recent sessions and links.
struct GameHomeView: View {
  @Environment(\.theme) private var theme
  @Environment(SessionsStore.self) private var sessions
  @Environment(PlayersStore.self) private var players

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        if let active = sessions.activeSession {
          progressCard(active)
        } else {
          hero
        }
        recentCard
        linksCard
      }
    }
    .navigationTitle("Game")
    .settingsToolbar()
    .navigationDestination(for: GameRoute.self) { route in
      GameDestination(route: route)
    }
  }

  // MARK: Pieces

  private var hero: some View {
    SectionCard {
      VStack(spacing: Spacing.md) {
        Image(systemName: "dice")
          .font(.system(size: 44))
          .foregroundStyle(theme.primary)
          .accessibilityHidden(true)
        Text("Ready for game night?")
          .font(Typography.h2)
          .fontDesign(.serif)
          .foregroundStyle(theme.text)
        Text("Keep score at the table. Payouts, dealer and money settle-up are automatic.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.center)
        NavigationLink(value: GameRoute.newGame) {
          Text("Start game night")
        }
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("game.start")
      }
      .frame(maxWidth: .infinity)
    }
  }

  private func progressCard(_ session: Session) -> some View {
    let model = SummaryModel(session: session)
    let names = players.nameMap(for: session.seatIDs)
    let leaders = model.leaderIDs.compactMap { names[$0] }
    return VStack(spacing: Spacing.md) {
      SectionCard("Game in progress") {
        VStack(alignment: .leading, spacing: Spacing.md) {
          HStack(spacing: Spacing.md) {
            GameAvatarRow(ids: session.seatIDs, size: 36)
            VStack(alignment: .leading, spacing: 2) {
              Text("\(session.hands.count) \(session.hands.count == 1 ? "hand" : "hands") played")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(theme.text)
              Text(leaders.isEmpty ? "Started \(session.createdAt.gameShortDate)" : "Leader: \(leaders.joined(separator: " & "))")
                .font(Typography.small)
                .foregroundStyle(theme.textMuted)
            }
            Spacer(minLength: 0)
          }
          NavigationLink(value: GameRoute.session(session.id)) {
            Text("Resume")
          }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("game.resume")
        }
      }
      NavigationLink(value: GameRoute.newGame) {
        Text("Start a new game night")
      }
      .buttonStyle(PrimaryButton(.secondary, size: .large))
      .accessibilityIdentifier("game.start")
    }
  }

  @ViewBuilder
  private var recentCard: some View {
    let recent = Array(sessions.finishedSessions.prefix(5))
    if !recent.isEmpty {
      SectionCard("Recent") {
        VStack(spacing: 0) {
          ForEach(recent) { session in
            NavigationLink(value: GameRoute.session(session.id)) {
              GameSessionRow(session: session)
            }
            .buttonStyle(.plain)
            if session.id != recent.last?.id { Divider().overlay(theme.border) }
          }
        }
      }
    }
  }

  private var linksCard: some View {
    SectionCard {
      VStack(spacing: 0) {
        NavigationLink(value: GameRoute.history) {
          ListRowView("All history") { chevron }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("game.history")
        Divider().overlay(theme.border)
        NavigationLink(value: GameRoute.players) {
          ListRowView("Players & stats") { chevron }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("game.players")
      }
    }
  }

  private var chevron: some View {
    Image(systemName: "chevron.right")
      .font(.footnote.weight(.semibold))
      .foregroundStyle(theme.textFaint)
      .accessibilityHidden(true)
  }
}

/// One finished session: date, who won, and the seated avatars.
struct GameSessionRow: View {
  @Environment(\.theme) private var theme
  @Environment(PlayersStore.self) private var players
  let session: Session

  var body: some View {
    let names = players.nameMap(for: session.seatIDs)
    ListRowView(session.createdAt.gameFullDate, subtitle: SummaryModel(session: session).winnerText(names: names)) {
      HStack(spacing: Spacing.sm) {
        GameAvatarRow(ids: session.seatIDs, size: 28)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(theme.textFaint)
          .accessibilityHidden(true)
      }
    }
  }
}

// MARK: - Navigation

/// Resolves a `GameRoute` to its screen.
struct GameDestination: View {
  let route: GameRoute

  var body: some View {
    switch route {
    case .newGame: NewGameView()
    case .session(let id): GameSessionView(sessionID: id)
    case .history: HistoryView()
    case .players: PlayersView()
    case .player(let id): PlayerStatsView(playerID: id)
    }
  }
}

/// Session setup that turns into the scoreboard in place once the game starts, so Back returns to the Game tab.
struct NewGameView: View {
  @State private var startedID: String?

  var body: some View {
    if let startedID {
      GameSessionView(sessionID: startedID)
    } else {
      SessionSetupView { startedID = $0 }
    }
  }
}

/// The scoreboard of a session, or its summary once the game night has ended.
struct GameSessionView: View {
  let sessionID: String
  @State private var showSummary = false

  var body: some View {
    if showSummary {
      SummaryView(sessionID: sessionID, onShowHands: { showSummary = false })
    } else {
      ScoreboardView(sessionID: sessionID, onShowSummary: { showSummary = true })
    }
  }
}

#if DEBUG
  #Preview("Light") {
    let stores = GameSamples.stores()
    return NavigationStack { GameHomeView() }
      .gameStores(stores.stores)
      .environment(\.theme, Theme.standard)
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    let stores = GameSamples.stores()
    return NavigationStack { GameHomeView() }
      .gameStores(stores.stores)
      .environment(\.theme, Theme.standard)
      .preferredColorScheme(.dark)
  }
#endif
