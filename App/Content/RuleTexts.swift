import Foundation
import MahjongCore

/// The words people read for every built-in rule (SPEC §17.4). Core holds behaviour only; the title,
/// "What it means", and a short example live here, keyed by rule id.
enum RuleTexts {
  struct Text: Equatable {
    var title: String
    var meaning: String
    /// A plain example for rules that do not pay differently (scoring rules get a live one).
    var example: String?
  }

  /// "Single", "Double", ...
  static func multipleName(_ multiple: Int) -> String {
    switch multiple {
    case 0: return "Nothing"
    case 1: return "Single"
    case 2: return "Double"
    case 3: return "Triple"
    case 4: return "Quadruple"
    default: return "\(multiple)\u{00D7}"
    }
  }

  /// "double", "triple", ... as it reads in a sentence.
  static func multipleWord(_ multiple: Int) -> String {
    switch multiple {
    case 0: return "nothing"
    case 1: return "the hand's value"
    case 2: return "double"
    case 3: return "triple"
    case 4: return "quadruple"
    default: return "\(multiple) times the hand's value"
    }
  }

  /// What someone pays, as it reads after "pays": "the hand's points", "double the hand's points".
  static func payPhrase(_ multiple: Int) -> String {
    switch multiple {
    case 0: return "nothing"
    case 1: return "the hand's points"
    case 2: return "double the hand's points"
    case 3: return "triple the hand's points"
    case 4: return "quadruple the hand's points"
    default: return "\(multiple) times the hand's points"
    }
  }

  static func multiple(of rule: HouseRule, default value: Int) -> Int { rule.multiple ?? value }

  /// The text of a rule given its current choice.
  static func text(for rule: HouseRule) -> Text {
    if let custom = rule.custom {
      var meaning = custom.text
      if let effect = custom.effect {
        let sentence = RuleSentences.sentence(for: effect)
        meaning = meaning.isEmpty ? sentence : "\(custom.text)\n\n\(sentence)"
      }
      return Text(title: custom.title, meaning: meaning, example: nil)
    }
    let m = rule.multiple
    switch rule.id {
    case RuleID.discarder:
      let word = multipleWord(m ?? 2)
      return Text(
        title: "The player who threw the winning tile pays \(word)",
        meaning:
          "When someone wins from a discard, the player who threw that tile pays \(payPhrase(m ?? 2)). "
          + "Switch it off and the thrower pays the same as everyone else.",
        example: nil)
    case RuleID.others:
      let word = multipleWord(m ?? 1)
      return Text(
        title: "Everyone else pays \(word)",
        meaning:
          "When someone wins from a discard, the other two losers pay \(payPhrase(m ?? 1))"
          + (m == 0 ? "." : ". Choose Nothing if only the thrower should pay."),
        example: nil)
    case RuleID.selfPick:
      let word = multipleWord(m ?? 2)
      return Text(
        title: "Self-pick: everyone pays \(word)",
        meaning:
          "If the winner drew the winning tile from the wall instead of taking a discard, every other player pays \(payPhrase(m ?? 2)).",
        example: nil)
    case RuleID.jokerless:
      let word = multipleWord(m ?? 2)
      return Text(
        title: "A jokerless hand pays \(word)",
        meaning:
          "If the winning hand uses no jokers, every payment is multiplied again: \(word). "
          + "Hands made only of singles and pairs can't use jokers anyway, so they don't get this bonus unless you switch that on below.",
        example: nil)
    case RuleID.discarderPaysAll:
      return Text(
        title: "The thrower pays for everyone",
        meaning:
          "When someone wins from a discard, the player who threw it pays what all three losers would have paid. Nobody else pays. Self-picks are not affected.",
        example: nil)
    case RuleID.wall:
      return Text(
        title: "Wall game: nobody pays",
        meaning:
          "If the wall runs out and nobody has won, no points change hands and the deal moves on.",
        example: "Everyone is still waiting when the last tile is drawn. Nobody wins or pays.")
    case RuleID.dealEast:
      return Text(
        title: "East starts with 14 tiles and goes first",
        meaning:
          "The dealer (East) is dealt 14 tiles and starts by discarding. Everyone else gets 13.",
        example: "In the Helper's Charleston, switch on \u{201C}I'm East\u{201D} to hold 14 tiles.")
    case RuleID.dealRotate:
      return Text(
        title: "The deal moves to the next player after every hand",
        meaning:
          "After a win or a wall game, East passes to the next seat in play order. The scoreboard keeps track.",
        example: "Alex deals the first hand, then Bea, then Cy, then Dee, then Alex again.")
    case RuleID.charlestonFirst:
      return Text(
        title: "First Charleston: pass 3 right, 3 across, 3 left",
        meaning:
          "Before play, everyone passes three tiles to the right, then three across, then three to the left. This pass is required.",
        example: nil)
    case RuleID.charlestonSecond:
      return Text(
        title: "Second Charleston: left, across, right",
        meaning:
          "A second round of three passes: left, across, then right. Any player may stop it before it starts. Switch this off if your table never plays it.",
        example: "The Helper's pass tracker shows 7 passes with it on, and 4 with it off.")
    case RuleID.courtesy:
      return Text(
        title: "Courtesy pass across: 0 to 3 tiles",
        meaning:
          "After the Charleston, you and the player opposite may swap up to 3 tiles. If you disagree on how many, the smaller number wins.",
        example: "You offer 2 tiles, the player across offers 3: you each swap 2.")
    case RuleID.blind:
      return Text(
        title: "Blind pass on the last pass",
        meaning:
          "On the last pass of a Charleston you may pass on tiles you just received without looking at them.",
        example: "You get 3 tiles from the left and hand them straight on to the right, unseen.")
    case RuleID.noJokers:
      return Text(
        title: "Jokers can't be passed",
        meaning:
          "You may never pass a joker in any Charleston pass. The Helper never suggests one.",
        example: nil)
    case RuleID.jokerGroups:
      return Text(
        title: "Jokers only in sets of 3 or more",
        meaning:
          "A joker can stand in for any tile in a pung, kong, quint or sextet. It can never be part of a single or a pair.",
        example: "Two 5 Dots and a joker make a pung of 5 Dots. One 5 Dot and a joker can't make a pair.")
    case RuleID.jokerExchange:
      return Text(
        title: "Joker exchange",
        meaning:
          "On your turn you may take a joker from any exposed set by putting down the real tile it stands for.",
        example: "Cy shows three 6 Dots with a joker in it. You hold a 6 Dot, so you put it down and take the joker.")
    case RuleID.calling:
      return Text(
        title: "Calling a discard",
        meaning:
          "You may take the last discard to complete an exposed set of 3 or more. You may take it for a single or a pair only if it wins the game.",
        example: nil)
    case RuleID.concealed:
      return Text(
        title: "Concealed hands (C)",
        meaning:
          "A hand marked C can't have exposed sets. You may call only the tile that wins.",
        example: nil)
    case RuleID.deadHand:
      return Text(
        title: "A dead hand still pays",
        meaning:
          "A player whose hand can no longer be made legally stops playing but still pays the winner. Switch it off if your table lets a dead hand off.",
        example: nil)
    case RuleID.blanks:
      return Text(
        title: "We play with blanks",
        meaning:
          "Some tables add blank tiles to the set. A blank never makes part of a hand. Switch this on to add a Blank key to the tile picker and let the Helper keep blanks in mind.",
        example: nil)
    default:
      return Text(title: rule.id, meaning: "", example: nil)
    }
  }

  /// The current choice in words for a rule's row ("Pays double"), or nil if it has none.
  static func choiceText(for rule: HouseRule) -> String? {
    if let custom = rule.custom {
      guard let effect = custom.effect else { return "A note for the table" }
      return RuleSentences.how(effect.action, payers: effect.payers)
    }
    let m = rule.multiple
    switch rule.id {
    case RuleID.discarder:
      return "Thrower pays \(multipleWord(m ?? 2))"
    case RuleID.others:
      return m == 0 ? "Others pay nothing" : "Others pay \(multipleWord(m ?? 1))"
    case RuleID.selfPick:
      return "Everyone pays \(multipleWord(m ?? 2))"
    case RuleID.jokerless:
      return "Pays \(multipleWord(m ?? 2))"
    case RuleID.blanks:
      return rule.isEnabled ? "\(rule.blanks?.count ?? 6) blanks" : nil
    default:
      return nil
    }
  }

  /// Heading for a built-in rule group in the rule book.
  static func categoryTitle(_ category: RuleCategory) -> String { category.title }

  static let lockedNote = "This is part of how the game is played, so it can't be switched off."
}
