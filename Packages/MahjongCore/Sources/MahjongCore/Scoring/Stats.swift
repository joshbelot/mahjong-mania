import Foundation

extension Scoring {
  /// Career stats for one player.
  ///
  /// - `biggestWin.points` is what the player collected on that hand.
  /// - `netCents` only counts sessions that had money turned on.
  /// - `sessionWins` counts ended sessions the player finished top of (ties count for everyone tied, and
  ///   a session where nobody is ahead of zero does not count).
  public static func playerStats(_ playerID: String, sessions: [Session]) -> PlayerStats {
    var stats = PlayerStats()
    var winPointsTotal = 0
    var lineCounts: [String: Int] = [:]

    for session in sessions where session.seatIDs.contains(playerID) {
      stats.sessionsPlayed += 1
      let sessionTotals = totals(session)
      let mine = sessionTotals[playerID] ?? 0
      stats.netPoints += mine
      if session.rules.money.enabled { stats.netCents += mine * session.rules.money.centsPerPoint }

      if session.endedAt != nil, let top = sessionTotals.values.max(), top > 0, mine == top {
        stats.sessionWins += 1
      }

      for hand in session.hands {
        guard case .mahjong(let input) = hand.kind else {
          if case .wall = hand.kind { stats.handsPlayed += 1 }
          continue
        }
        stats.handsPlayed += 1
        if input.discarderID == playerID && input.winnerID != playerID {
          stats.timesDiscardedWinner += 1
        }
        guard input.winnerID == playerID else { continue }
        stats.wins += 1
        winPointsTotal += input.basePoints
        let selfPick = input.discarderID == nil || input.discarderID == input.winnerID
        if selfPick { stats.selfPicks += 1 }
        if input.jokerless { stats.jokerlessWins += 1 }
        let collected = hand.payments[playerID] ?? 0
        if collected > (stats.biggestWin?.points ?? 0) {
          stats.biggestWin = BiggestWin(points: collected, lineLabel: input.lineLabel, date: hand.createdAt)
        }
        if let label = input.lineLabel, !label.isEmpty { lineCounts[label, default: 0] += 1 }
      }
    }

    if stats.handsPlayed > 0 { stats.winRate = Double(stats.wins) / Double(stats.handsPlayed) }
    if stats.wins > 0 { stats.avgWinPoints = Double(winPointsTotal) / Double(stats.wins) }
    stats.favoriteLines = lineCounts
      .map { LineCount(label: $0.key, count: $0.value) }
      .sorted { $0.count != $1.count ? $0.count > $1.count : $0.label < $1.label }
      .prefix(3).map { $0 }
    return stats
  }

  /// Wins per line ID on a card ("You've won this 3 times").
  public static func lineWins(cardID: String, sessions: [Session]) -> [String: Int] {
    var result: [String: Int] = [:]
    for session in sessions {
      for hand in session.hands {
        if case .mahjong(let input) = hand.kind, input.cardID == cardID, let lineID = input.lineID {
          result[lineID, default: 0] += 1
        }
      }
    }
    return result
  }
}
