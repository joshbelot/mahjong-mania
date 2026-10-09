import MahjongCore
import SwiftUI

/// Final standings, highlights and the money settle-up for a game night.
struct SummaryView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  let sessionID: String
  let onShowHands: () -> Void

  var body: some View {
    Group {
      if let session = sessions.session(id: sessionID) {
        content(session)
      } else {
        EmptyStateView("Game night not found", systemImage: "questionmark.folder")
      }
    }
    .background(theme.bg)
  }

  @ViewBuilder
  private func content(_ session: Session) -> some View {
    let model = SummaryModel(session: session)
    let names = players.nameMap(for: session.seatIDs)
    let shareText = model.shareText(names: names, dateText: session.createdAt.gameFullDate)

    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        header(session)
        standingsCard(model, session: session)
        highlightsCard(model, names: names)
        settleCard(model, names: names)
        VStack(spacing: Spacing.md) {
          ShareLink(item: shareText) {
            Label("Share summary", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("summary.share")
          Button("View hand log", action: onShowHands)
            .buttonStyle(PrimaryButton(.secondary, size: .large))
            .accessibilityIdentifier("summary.hands")
          Button("Done") { dismiss() }
            .buttonStyle(PrimaryButton(.ghost, size: .large))
            .accessibilityIdentifier("summary.done")
        }
      }
    }
    .navigationTitle("Summary")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func header(_ session: Session) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text("Game night")
        .titleStyle()
        .foregroundStyle(theme.text)
      Text("\(session.createdAt.gameFullDate) \u{00B7} \(session.hands.count) \(session.hands.count == 1 ? "hand" : "hands")")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
    }
  }

  private func standingsCard(_ model: SummaryModel, session: Session) -> some View {
    SectionCard("Standings") {
      VStack(spacing: 0) {
        ForEach(model.standings) { standing in
          let name = players.name(of: standing.id)
          let isLeader = model.leaderIDs.contains(standing.id)
          HStack(spacing: Spacing.md) {
            Text("\(standing.rank)")
              .font(Typography.small.weight(.bold))
              .foregroundStyle(isLeader ? theme.onPrimary : theme.textMuted)
              .frame(width: 24, height: 24)
              .background(isLeader ? theme.gold : theme.surfaceAlt, in: Circle())
              .accessibilityHidden(true)
            AvatarView(name: name, colorIndex: players.colorIndex(of: standing.id), size: 40)
            HStack(spacing: Spacing.xs) {
              Text(name)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
              if isLeader {
                Image(systemName: "crown.fill")
                  .font(.footnote)
                  .foregroundStyle(theme.gold)
                  .accessibilityLabel("Winner")
              }
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
              PointsText(standing.points)
              if session.rules.money.enabled {
                MoneyText(cents: standing.cents, symbol: session.rules.money.currencySymbol)
              }
            }
          }
          .frame(minHeight: 56)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("standing.\(name)")
          if standing.id != model.standings.last?.id { Divider().overlay(theme.border) }
        }
      }
    }
  }

  private func highlightsCard(_ model: SummaryModel, names: [String: String]) -> some View {
    let highlights = model.highlights(names: names)
    return SectionCard("Highlights") {
      if highlights.isEmpty {
        Text("No hands were played.")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
      } else {
        VStack(alignment: .leading, spacing: Spacing.md) {
          ForEach(highlights) { highlight in
            VStack(alignment: .leading, spacing: 2) {
              Text(highlight.title)
                .tinyStyle()
                .foregroundStyle(theme.textMuted)
              Text(highlight.value)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(theme.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("highlight.\(highlight.title)")
          }
        }
      }
    }
  }

  private func settleCard(_ model: SummaryModel, names: [String: String]) -> some View {
    let lines = model.settleLines(names: names)
    return SectionCard("Settle up") {
      if !model.session.rules.money.enabled {
        Text("Money was off for this game night, so the standings are in points only.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else if lines.isEmpty {
        Text("All square. Nobody owes anything.")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .accessibilityIdentifier("settle.none")
      } else {
        VStack(alignment: .leading, spacing: Spacing.sm) {
          ForEach(Array(lines.enumerated()), id: \.offset) { entry in
            HStack(spacing: Spacing.sm) {
              Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(theme.primary)
                .accessibilityHidden(true)
              Text(entry.element)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(theme.text)
                .accessibilityIdentifier("settle.line.\(entry.offset)")
            }
            .frame(minHeight: 36, alignment: .leading)
          }
        }
      }
    }
  }
}

#if DEBUG
  #Preview("Light") {
    let sample = GameSamples.stores(ended: true)
    return NavigationStack { SummaryView(sessionID: sample.sessionID, onShowHands: {}) }
      .gameStores(sample.stores)
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    let sample = GameSamples.stores(ended: true)
    return NavigationStack { SummaryView(sessionID: sample.sessionID, onShowHands: {}) }
      .gameStores(sample.stores)
      .preferredColorScheme(.dark)
  }
#endif
