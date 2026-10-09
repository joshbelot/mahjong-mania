import MahjongCore
import SwiftUI

/// The player roster with wins and net points. Tap a player for their stats.
struct PlayersView: View {
  @Environment(\.theme) private var theme
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  @State private var showAdd = false
  @State private var newName = ""

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        if players.activePlayers.isEmpty {
          EmptyStateView(
            "No players yet", systemImage: "person.2",
            message: "Add the people you play with. They are reused for every game night.",
            actionTitle: "Add player"
          ) { showAdd = true }
        } else {
          SectionCard {
            VStack(spacing: 0) {
              ForEach(players.activePlayers) { player in
                NavigationLink(value: GameRoute.player(player.id)) {
                  row(player)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("players.row.\(player.name)")
                if player.id != players.activePlayers.last?.id { Divider().overlay(theme.border) }
              }
            }
          }
        }
        if !players.archivedPlayers.isEmpty {
          SectionCard("Archived") {
            VStack(spacing: 0) {
              ForEach(players.archivedPlayers) { player in
                HStack(spacing: Spacing.md) {
                  AvatarView(name: player.name, colorIndex: player.colorIndex, size: 36)
                  Text(player.name)
                    .font(Typography.body)
                    .foregroundStyle(theme.textMuted)
                  Spacer(minLength: Spacing.sm)
                  Button("Restore") { players.setArchived(id: player.id, false) }
                    .buttonStyle(PrimaryButton(.ghost))
                }
                .frame(minHeight: 52)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Players")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showAdd = true
        } label: {
          Label("Add player", systemImage: "plus")
        }
        .accessibilityIdentifier("players.add")
      }
    }
    .alert("New player", isPresented: $showAdd) {
      TextField("Name", text: $newName)
      Button("Add") {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { players.add(name: trimmed) }
        newName = ""
      }
      Button("Cancel", role: .cancel) { newName = "" }
    }
  }

  private func row(_ player: Player) -> some View {
    let stats = Scoring.playerStats(player.id, sessions: sessions.sessions)
    return HStack(spacing: Spacing.md) {
      AvatarView(name: player.name, colorIndex: player.colorIndex, size: 44)
      VStack(alignment: .leading, spacing: 2) {
        Text(player.name)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
        Text("\(stats.wins) \(stats.wins == 1 ? "win" : "wins") \u{00B7} \(stats.sessionsPlayed) \(stats.sessionsPlayed == 1 ? "game night" : "game nights")")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
      Spacer(minLength: Spacing.sm)
      PointsText(stats.netPoints)
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(theme.textFaint)
        .accessibilityHidden(true)
    }
    .frame(minHeight: 60)
    .contentShape(Rectangle())
  }
}

/// A player's career stats, favourite hands, and rename / colour / archive.
struct PlayerStatsView: View {
  @Environment(\.theme) private var theme
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  let playerID: String
  @State private var showRename = false
  @State private var renameText = ""
  @State private var confirmArchive = false

  var body: some View {
    Group {
      if let player = players.player(id: playerID) {
        content(player)
      } else {
        EmptyStateView("Player not found", systemImage: "person.crop.circle.badge.questionmark")
      }
    }
    .background(theme.bg)
  }

  @ViewBuilder
  private func content(_ player: Player) -> some View {
    let stats = Scoring.playerStats(player.id, sessions: sessions.sessions)
    let usedMoney = sessions.sessions.contains {
      $0.seatIDs.contains(player.id) && $0.rules.money.enabled
    }
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
          AvatarView(name: player.name, colorIndex: player.colorIndex, size: 64)
          VStack(alignment: .leading, spacing: 2) {
            Text(player.name)
              .titleStyle()
              .foregroundStyle(theme.text)
              .lineLimit(1)
            if player.archived {
              Text("Archived")
                .font(Typography.small)
                .foregroundStyle(theme.textMuted)
            }
          }
        }
        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible())],
          spacing: Spacing.md
        ) {
          GameStatTile(title: "Game nights", value: "\(stats.sessionsPlayed)")
          GameStatTile(title: "Night wins", value: "\(stats.sessionWins)")
          GameStatTile(title: "Hands", value: "\(stats.handsPlayed)")
          GameStatTile(title: "Wins", value: "\(stats.wins)")
          GameStatTile(title: "Win rate", value: "\(Int((stats.winRate * 100).rounded()))%")
          GameStatTile(title: "Average win", value: "\(Int(stats.avgWinPoints.rounded())) pts")
          GameStatTile(title: "Self-picks", value: "\(stats.selfPicks)")
          GameStatTile(title: "Jokerless wins", value: "\(stats.jokerlessWins)")
          GameStatTile(
            title: "Biggest win", value: stats.biggestWin.map { "\($0.points) pts" } ?? "None",
            detail: stats.biggestWin?.lineLabel)
          GameStatTile(title: "Threw the winner", value: "\(stats.timesDiscardedWinner)")
          GameStatTile(title: "Net points", value: PointsText.format(stats.netPoints))
          if usedMoney {
            GameStatTile(title: "Net money", value: Scoring.formatMoney(cents: stats.netCents, symbol: "$"))
          }
        }
        favoritesCard(stats)
        manageCard(player)
      }
    }
    .navigationTitle(player.name)
    .navigationBarTitleDisplayMode(.inline)
    .alert("Rename player", isPresented: $showRename) {
      TextField("Name", text: $renameText)
      Button("Save") {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { players.rename(id: player.id, to: trimmed) }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Archive \(player.name)?", isPresented: $confirmArchive, titleVisibility: .visible
    ) {
      Button("Archive", role: .destructive) { players.setArchived(id: player.id, true) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Their history stays. They will not appear when you start a game night.")
    }
  }

  private func favoritesCard(_ stats: PlayerStats) -> some View {
    SectionCard("Favourite hands") {
      if stats.favoriteLines.isEmpty {
        Text("Pick hands from a card when you record a win and your favourites show up here.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else {
        VStack(spacing: 0) {
          ForEach(stats.favoriteLines, id: \.label) { line in
            ListRowView(line.label) {
              Text("\u{00D7}\(line.count)")
                .font(Typography.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(theme.textMuted)
            }
          }
        }
      }
    }
  }

  private func manageCard(_ player: Player) -> some View {
    SectionCard("Manage") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text("Colour")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        FlowLayout(spacing: 0, lineSpacing: 0) {
          ForEach(0..<PlayerPalette.hexes.count, id: \.self) { index in
            Button {
              players.setColor(id: player.id, index: index)
            } label: {
              Circle()
                .fill(PlayerPalette.color(at: index))
                .frame(width: 30, height: 30)
                .overlay(
                  Circle().strokeBorder(theme.text, lineWidth: index == player.colorIndex ? 3 : 0)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Colour \(index + 1)")
            .accessibilityAddTraits(index == player.colorIndex ? .isSelected : [])
          }
        }
        HStack(spacing: Spacing.md) {
          Button("Rename") {
            renameText = player.name
            showRename = true
          }
          .buttonStyle(PrimaryButton(.secondary))
          .accessibilityIdentifier("player.rename")
          if player.archived {
            Button("Restore") { players.setArchived(id: player.id, false) }
              .buttonStyle(PrimaryButton(.secondary))
          } else {
            Button("Archive") { confirmArchive = true }
              .buttonStyle(PrimaryButton(.secondary))
              .accessibilityIdentifier("player.archive")
          }
        }
      }
    }
  }
}

/// One number with a caption, for the stats grid.
struct GameStatTile: View {
  @Environment(\.theme) private var theme
  let title: String
  let value: String
  var detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .tinyStyle()
        .foregroundStyle(theme.textMuted)
      Text(value)
        .font(.system(.title2, design: .rounded, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(theme.text)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      if let detail {
        Text(detail)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .padding(Spacing.md)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}

#if DEBUG
  #Preview("Players light") {
    NavigationStack { PlayersView() }
      .gameStores(GameSamples.stores(ended: true).stores)
      .preferredColorScheme(.light)
  }

  #Preview("Players dark") {
    NavigationStack { PlayersView() }
      .gameStores(GameSamples.stores(ended: true).stores)
      .preferredColorScheme(.dark)
  }

  #Preview("Stats light") {
    let sample = GameSamples.stores(ended: true)
    return NavigationStack {
      PlayerStatsView(playerID: sample.stores.players.players.first?.id ?? "")
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.light)
  }

  #Preview("Stats dark") {
    let sample = GameSamples.stores(ended: true)
    return NavigationStack {
      PlayerStatsView(playerID: sample.stores.players.players.first?.id ?? "")
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.dark)
  }
#endif
