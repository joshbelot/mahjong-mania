import MahjongCore
import SwiftUI

/// Finished game nights grouped by month. Tapping one opens its read-only scoreboard.
struct HistoryView: View {
  @Environment(\.theme) private var theme
  @Environment(SessionsStore.self) private var sessions

  var body: some View {
    let groups = HistoryGrouping.byMonth(sessions.finishedSessions)
    ScreenContainer {
      if groups.isEmpty {
        EmptyStateView(
          "No game nights yet", systemImage: "clock.arrow.circlepath",
          message: "Finished game nights show up here.")
      } else {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          ForEach(groups) { group in
            SectionCard(group.month.formatted(.dateTime.month(.wide).year())) {
              VStack(spacing: 0) {
                ForEach(group.sessions) { session in
                  NavigationLink(value: GameRoute.session(session.id)) {
                    GameSessionRow(session: session)
                  }
                  .buttonStyle(.plain)
                  .accessibilityIdentifier("history.session")
                  if session.id != group.sessions.last?.id { Divider().overlay(theme.border) }
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#if DEBUG
  #Preview("Light") {
    NavigationStack { HistoryView() }
      .gameStores(GameSamples.stores(ended: true).stores)
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    NavigationStack { HistoryView() }
      .gameStores(GameSamples.stores(ended: true).stores)
      .preferredColorScheme(.dark)
  }
#endif
