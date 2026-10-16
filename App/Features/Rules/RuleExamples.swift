import Foundation
import MahjongCore

/// Plain-language sentences for custom scoring rules (the three pickers read as one sentence).
enum RuleSentences {
  static func when(_ condition: RuleCondition) -> String {
    switch condition {
    case .always: return "On every win"
    case .selfPick: return "On a self-pick"
    case .discard: return "On a win from a discard"
    case .jokerless: return "On a jokerless hand"
    case .concealedHand: return "On a concealed hand"
    case .eastWins: return "When East wins"
    case .section(let name): return "On a hand from \(name)"
    case .line(_, let label): return "On \(label)"
    }
  }

  static func who(_ payers: PayerScope) -> String {
    switch payers {
    case .everyone: return "everyone pays"
    case .discarderOnly: return "the thrower pays"
    case .everyoneButDiscarder: return "everyone except the thrower pays"
    }
  }

  /// "double", "triple", "quadruple", "4 times the hand's value", "5 extra points".
  static func how(_ action: RuleAction) -> String {
    switch action {
    case .multiply(let n):
      switch n {
      case 2: return "double"
      case 3: return "triple"
      case 4: return "quadruple"
      default: return "\(n) times the hand's value"
      }
    case .addPoints(let n): return "\(n) extra \(n == 1 ? "point" : "points")"
    }
  }

  /// A short phrase for a rule row: "Everyone pays double".
  static func how(_ action: RuleAction, payers: PayerScope) -> String {
    "\(who(payers).prefix(1).uppercased())\(who(payers).dropFirst()) \(how(action))"
  }

  /// "On a self-pick, everyone pays double."
  static func sentence(for effect: CustomEffect) -> String {
    "\(when(effect.condition)), \(who(effect.payers)) \(how(effect.action))."
  }

  /// The title filled in from the sentence: "On a self-pick: everyone pays double".
  static func autoTitle(for effect: CustomEffect) -> String {
    "\(when(effect.condition)): \(who(effect.payers)) \(how(effect.action))"
  }
}

/// A worked example of how a hand pays under a rule book, for the rule detail screens.
enum RuleExamples {
  static let winner = "Bea"
  static let thrower = "Cy"
  static let seats = ["Bea", "Cy", "Dee", "Al"]

  struct Scenario: Equatable {
    var selfPick = false
    var jokerless = false
    var concealed = false
    var eastWins = false
    var noJokerGroups = false
    var section: String?
    var lineID: String?
    var lineLabel: String?

    static let discard = Scenario()
    static let selfPicked = Scenario(selfPick: true)
    static let jokerlessDiscard = Scenario(jokerless: true)
  }

  /// The scenario that shows a rule at work.
  static func scenario(forRule id: String) -> Scenario {
    switch id {
    case RuleID.selfPick: return .selfPicked
    case RuleID.jokerless: return .jokerlessDiscard
    default: return .discard
    }
  }

  static func scenario(for condition: RuleCondition) -> Scenario {
    switch condition {
    case .selfPick: return .selfPicked
    case .jokerless: return .jokerlessDiscard
    case .concealedHand: return Scenario(concealed: true)
    case .eastWins: return Scenario(eastWins: true)
    case .section(let name): return Scenario(section: name)
    case .line(let id, let label): return Scenario(lineID: id, lineLabel: label)
    case .always, .discard: return .discard
    }
  }

  static func payments(_ scenario: Scenario, rules: RuleSet, base: Int = 25) -> [String: Int] {
    let input = MahjongInput(
      winnerID: winner, discarderID: scenario.selfPick ? nil : thrower, lineID: scenario.lineID,
      lineLabel: scenario.lineLabel, basePoints: base, jokerless: scenario.jokerless,
      lineHasNoJokerGroups: scenario.noJokerGroups, lineSection: scenario.section,
      lineConcealed: scenario.concealed)
    return Scoring.payments(
      for: .mahjong(input), seats: seats, dealerID: scenario.eastWins ? winner : "Dee", rules: rules)
  }

  /// "Bea wins a 25-point hand from Cy's discard: Cy pays 50, Dee and Al pay 25 each. Bea collects 100."
  static func text(_ scenario: Scenario, rules: RuleSet, base: Int = 25) -> String {
    let paid = payments(scenario, rules: rules, base: base)
    var intro = "\(winner) wins a \(base)-point hand"
    if scenario.selfPick {
      intro += " by drawing the winning tile"
    } else {
      intro += " from \(thrower)'s discard"
    }
    var details: [String] = []
    if scenario.jokerless { details.append("with no jokers") }
    if scenario.concealed { details.append("a concealed hand") }
    if scenario.eastWins { details.append("as East") }
    if let label = scenario.lineLabel { details.append("with \(label)") }
    if let section = scenario.section { details.append("from \(section)") }
    if !details.isEmpty { intro += " (\(details.joined(separator: ", ")))" }

    // Group the losers by what they pay, keeping seat order.
    var groups: [(amount: Int, names: [String])] = []
    for seat in seats where seat != winner {
      let amount = -(paid[seat] ?? 0)
      if let index = groups.firstIndex(where: { $0.amount == amount }) {
        groups[index].names.append(seat)
      } else {
        groups.append((amount, [seat]))
      }
    }
    let phrases = groups.map { group -> String in
      let who = joined(group.names)
      if group.amount == 0 { return "\(who) pay\(group.names.count == 1 ? "s" : "") nothing" }
      let each = group.names.count > 1 ? " each" : ""
      return "\(who) pay\(group.names.count == 1 ? "s" : "") \(group.amount)\(each)"
    }
    return "\(intro): \(phrases.joined(separator: ", ")). \(winner) collects \(paid[winner] ?? 0)."
  }

  static func joined(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
  }

  /// The live example for a rule, or nil for rules that do not change payments.
  static func example(forRule rule: HouseRule, in rules: RuleSet) -> String? {
    if let effect = rule.custom?.effect {
      return text(scenario(for: effect.condition), rules: rules)
    }
    switch rule.id {
    case RuleID.discarder, RuleID.others, RuleID.discarderPaysAll, RuleID.selfPick, RuleID.jokerless:
      return text(scenario(forRule: rule.id), rules: rules)
    default:
      return nil
    }
  }
}
