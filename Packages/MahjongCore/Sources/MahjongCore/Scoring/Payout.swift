import Foundation

extension Scoring {
  /// Points moved by one hand. The result has an entry for every seat and always sums to zero.
  /// `dealerID` is East for this hand (used by "East wins" rules).
  ///
  /// A `discarderID` that is the winner or not seated is treated as a self-pick; the UI never produces it.
  public static func payments(
    for kind: HandKind, seats: [String], dealerID: String?, rules: RuleSet
  ) -> [String: Int] {
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

      var thrower: String?
      if let id = input.discarderID, id != input.winnerID, seats.contains(id) { thrower = id }

      let jokerlessApplies =
        input.jokerless
        && (input.lineHasNoJokerGroups ? (rules.rule(RuleID.jokerless)?.includeNoJokerHands ?? false) : true)
      let jokerlessFactor = jokerlessApplies ? rules.roleMultiple(RuleID.jokerless) : 1
      let customs = rules.rules.filter { $0.isEnabled && $0.custom?.effect != nil }

      var owed: [String: Int] = [:]
      for seat in seats where seat != input.winnerID {
        // 1. The role multiple.
        var factor: Int
        if thrower == nil {
          factor = rules.roleMultiple(RuleID.selfPick)
        } else if seat == thrower {
          factor = rules.roleMultiple(RuleID.discarder)
        } else {
          factor = rules.roleMultiple(RuleID.others)
        }
        // 2. Jokerless.
        factor *= jokerlessFactor
        // 3. Custom multiples.
        var extra = 0
        for rule in customs {
          guard let effect = rule.custom?.effect,
            applies(effect, to: seat, input: input, thrower: thrower, dealerID: dealerID)
          else { continue }
          switch effect.action {
          case .multiply(let n): factor *= n
          case .addPoints(let n): extra += n
          }
        }
        // 4. Points, then custom additions.
        owed[seat] = input.basePoints * factor + extra
      }

      // 5. "The thrower pays for everyone".
      if rules.isOn(RuleID.discarderPaysAll), let thrower {
        let total = owed.values.reduce(0, +)
        for seat in owed.keys { owed[seat] = seat == thrower ? total : 0 }
      }

      // 6. The winner collects the total.
      var collected = 0
      for (seat, amount) in owed {
        result[seat] = -amount
        collected += amount
      }
      result[input.winnerID] = collected
      return result
    }
  }

  /// The enabled custom scoring rules that changed what someone paid on this hand (for the
  /// "why did it pay that?" explanation).
  public static func appliedCustomRules(
    for input: MahjongInput, seats: [String], dealerID: String?, rules: RuleSet
  ) -> [HouseRule] {
    guard seats.contains(input.winnerID) else { return [] }
    var thrower: String?
    if let id = input.discarderID, id != input.winnerID, seats.contains(id) { thrower = id }
    return rules.rules.filter { rule in
      guard rule.isEnabled, let effect = rule.custom?.effect else { return false }
      return seats.contains { seat in
        seat != input.winnerID
          && applies(effect, to: seat, input: input, thrower: thrower, dealerID: dealerID)
      }
    }
  }

  /// Whether a custom scoring rule changes what `seat` pays on this hand.
  static func applies(
    _ effect: CustomEffect, to seat: String, input: MahjongInput, thrower: String?, dealerID: String?
  ) -> Bool {
    switch effect.condition {
    case .always: break
    case .selfPick: if thrower != nil { return false }
    case .discard: if thrower == nil { return false }
    case .jokerless: if !input.jokerless { return false }
    case .concealedHand: if !input.lineConcealed { return false }
    case .eastWins: if dealerID == nil || input.winnerID != dealerID { return false }
    case .section(let name): if input.lineSection != name { return false }
    case .line(let id, _): if input.lineID != id { return false }
    }
    switch effect.payers {
    case .everyone: return true
    case .discarderOnly: return thrower != nil && seat == thrower
    case .everyoneButDiscarder: return seat != thrower
    }
  }
}
