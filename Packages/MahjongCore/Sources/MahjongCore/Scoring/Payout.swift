import Foundation

extension Scoring {
  /// Points moved by one hand. The result has an entry for every seat and always sums to zero.
  ///
  /// A `discarderID` that is the winner or not seated is treated as a self-pick; the UI never produces it.
  public static func payments(for kind: HandKind, seats: [String], rules: RuleSet) -> [String: Int] {
    var result: [String: Int] = [:]
    for seat in seats { result[seat] = 0 }

    switch kind {
    case .wall:
      return result

    case .adjustment(let fromID, let toID, let points, _):
      result[fromID, default: 0] -= points
      result[toID, default: 0] += points
      return result

    case .mahjong(let input):
      guard seats.contains(input.winnerID) else { return result }
      let base = input.basePoints
      let jokerless = input.jokerless && (input.lineHasNoJokerGroups ? rules.jokerlessBonusForNoJokerLines : true)
      let bonus = jokerless ? rules.jokerlessMultiplier : 1

      var discarder: String?
      if let thrower = input.discarderID, thrower != input.winnerID, seats.contains(thrower) {
        discarder = thrower
      }

      var collected = 0
      for seat in seats where seat != input.winnerID {
        let owed: Int
        if let discarder {
          owed =
            base * (seat == discarder ? rules.discarderMultiplier : rules.othersOnDiscardMultiplier) * bonus
        } else {
          owed = base * rules.selfPickMultiplier * bonus
        }
        result[seat] = -owed
        collected += owed
      }
      result[input.winnerID] = collected
      return result
    }
  }
}
