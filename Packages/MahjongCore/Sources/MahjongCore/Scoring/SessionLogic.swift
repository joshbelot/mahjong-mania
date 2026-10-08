import Foundation

extension Scoring {
  /// East for the next hand: advances one seat per Mahjong or wall game.
  public static func currentDealerID(_ s: Session) -> String {
    guard !s.seatIDs.isEmpty else { return "" }
    let advances = s.hands.filter { $0.kind.advancesDealer }.count
    return s.seatIDs[((s.startDealerIndex + advances) % s.seatIDs.count + s.seatIDs.count) % s.seatIDs.count]
  }

  public static func adding(_ kind: HandKind, to s: Session, id: String, at: Date) -> Session {
    var session = s
    session.hands.append(
      HandRecord(
        id: id, createdAt: at, dealerID: currentDealerID(s), kind: kind,
        payments: payments(for: kind, seats: s.seatIDs, rules: s.rules)))
    return session
  }

  public static func editing(handID: String, to kind: HandKind, in s: Session) -> Session {
    guard let index = s.hands.firstIndex(where: { $0.id == handID }) else { return s }
    var session = s
    session.hands[index].kind = kind
    return recomputed(session)
  }

  public static func removing(handID: String, from s: Session) -> Session {
    var session = s
    session.hands.removeAll { $0.id == handID }
    return recomputed(session)
  }

  public static func undoingLast(_ s: Session) -> Session {
    guard !s.hands.isEmpty else { return s }
    var session = s
    session.hands.removeLast()
    return session
  }

  /// Replaces the rules snapshot and recomputes every hand's payments.
  public static func withRules(_ r: RuleSet, _ s: Session) -> Session {
    var session = s
    session.rules = r
    return recomputed(session)
  }

  public static func ending(_ s: Session, at: Date) -> Session {
    var session = s
    session.endedAt = at
    return session
  }

  public static func reopening(_ s: Session) -> Session {
    var session = s
    session.endedAt = nil
    return session
  }

  /// Points per player (every seat is present, zero if nothing happened yet).
  public static func totals(_ s: Session) -> [String: Int] {
    var result: [String: Int] = [:]
    for seat in s.seatIDs { result[seat] = 0 }
    for hand in s.hands {
      for (id, points) in hand.payments { result[id, default: 0] += points }
    }
    return result
  }

  /// Cents per player using the session's `centsPerPoint`.
  public static func moneyTotals(_ s: Session) -> [String: Int] {
    totals(s).mapValues { $0 * s.rules.money.centsPerPoint }
  }

  /// Re-derives each hand's dealer and payments from its kind, the seats and the rules.
  static func recomputed(_ s: Session) -> Session {
    var session = s
    var advances = 0
    for index in session.hands.indices {
      let seatCount = max(session.seatIDs.count, 1)
      let seat = ((session.startDealerIndex + advances) % seatCount + seatCount) % seatCount
      session.hands[index].dealerID = session.seatIDs.isEmpty ? "" : session.seatIDs[seat]
      session.hands[index].payments = payments(
        for: session.hands[index].kind, seats: session.seatIDs, rules: session.rules)
      if session.hands[index].kind.advancesDealer { advances += 1 }
    }
    return session
  }
}
