import Foundation

struct GlossaryEntry: Sendable, Hashable, Identifiable {
  let term: String
  let definition: String
  var id: String { term }
}

enum Glossary {
  /// Sorted alphabetically (case-insensitive) by term.
  static let entries: [GlossaryEntry] = raw.sorted {
    $0.term.lowercased() < $1.term.lowercased()
  }

  private static let raw: [GlossaryEntry] = [
    GlossaryEntry(
      term: "Bam",
      definition:
        "A tile from the bamboo suit, numbered 1 to 9 and shown in green. The 1 Bam is often a bird."
    ),
    GlossaryEntry(
      term: "Blind pass",
      definition:
        "On the last pass of a Charleston, handing on 1 to 3 tiles you just received without looking at them."
    ),
    GlossaryEntry(
      term: "Calling",
      definition:
        "Claiming another player's fresh discard to finish a group of three or more, or to win. You then show the group on the table."
    ),
    GlossaryEntry(
      term: "Charleston",
      definition:
        "The tile swap at the start of a game, where everyone passes unwanted tiles to the right, across and left. A second round and a courtesy pass may follow."
    ),
    GlossaryEntry(
      term: "Concealed (C)",
      definition:
        "A hand marked C stays hidden until you win. You may call only the last tile, and any earlier exposure makes the hand impossible."
    ),
    GlossaryEntry(
      term: "Consecutive run",
      definition:
        "Numbers that follow each other, like 3, 4, 5, 6. Lines marked as any consecutive numbers can slide up or down as long as they stay within 1 to 9."
    ),
    GlossaryEntry(
      term: "Courtesy pass",
      definition:
        "An optional last swap of 0 to 3 tiles with the player across from you. If you disagree on the number, the smaller one wins."
    ),
    GlossaryEntry(
      term: "Crak",
      definition:
        "A tile from the Characters suit, numbered 1 to 9 and shown in red. Short for Character, and also spelled Crack."
    ),
    GlossaryEntry(
      term: "Dead hand",
      definition:
        "A hand that can no longer be completed legally. The player stops trying to win but still pays the winner."
    ),
    GlossaryEntry(
      term: "Dot",
      definition:
        "A tile from the circles suit, numbered 1 to 9 and shown in blue."
    ),
    GlossaryEntry(
      term: "Dragon",
      definition:
        "One of the Red, Green or White honour tiles, four of each. Each dragon goes with a suit."
    ),
    GlossaryEntry(
      term: "East (Dealer)",
      definition:
        "The player who starts the hand with 14 tiles and discards first. East moves to the next seat after each hand."
    ),
    GlossaryEntry(
      term: "Exposed (X)",
      definition:
        "A hand marked X lets you call discards for groups of three or more and show them on the table."
    ),
    GlossaryEntry(
      term: "Exposure",
      definition:
        "A group of tiles placed face up in front of your rack after a call."
    ),
    GlossaryEntry(
      term: "Family (Section)",
      definition:
        "A themed block of lines on a card, such as even numbers or winds and dragons."
    ),
    GlossaryEntry(
      term: "Flower",
      definition:
        "One of 8 bonus-style tiles that all count as the same tile, so any flower fits any flower slot."
    ),
    GlossaryEntry(
      term: "Hot tile",
      definition:
        "A tile that is likely to finish someone else's hand, so throwing it away is risky."
    ),
    GlossaryEntry(
      term: "Joker",
      definition:
        "A wild tile (8 in a set) that can stand in for any tile, but only in groups of three or more."
    ),
    GlossaryEntry(
      term: "Joker exchange",
      definition:
        "On your turn, swapping the natural tile a joker stands for into an exposure and taking the joker. Also called redeeming a joker."
    ),
    GlossaryEntry(
      term: "Jokerless",
      definition:
        "Winning without any joker in your hand. It pays double on top of other bonuses, unless the hand could never use jokers."
    ),
    GlossaryEntry(
      term: "Kong",
      definition: "A group of four identical tiles."
    ),
    GlossaryEntry(
      term: "Like numbers",
      definition:
        "The same number in different suits, such as a 4 in Cracks, Bams and Dots."
    ),
    GlossaryEntry(
      term: "Mahjong",
      definition:
        "The winning call, made when your 14 tiles match a line on the card. It also names the whole game."
    ),
    GlossaryEntry(
      term: "Matching dragon",
      definition:
        "The dragon that goes with a suit: Red with Cracks, Green with Bams and White (Soap) with Dots."
    ),
    GlossaryEntry(
      term: "Pair",
      definition:
        "Two identical tiles. Jokers cannot be used in a pair."
    ),
    GlossaryEntry(
      term: "Pung",
      definition: "A group of three identical tiles."
    ),
    GlossaryEntry(
      term: "Quint",
      definition:
        "A group of five identical tiles. It needs at least one joker, because only four natural copies exist."
    ),
    GlossaryEntry(
      term: "Rack",
      definition:
        "The small ledge in front of each player that holds their hidden tiles."
    ),
    GlossaryEntry(
      term: "Self-pick",
      definition:
        "Winning with a tile you drew yourself. Everyone pays double."
    ),
    GlossaryEntry(
      term: "Sextet",
      definition:
        "A group of six identical tiles. It needs at least two jokers."
    ),
    GlossaryEntry(
      term: "Single",
      definition:
        "One lone tile in a hand. Jokers cannot stand in for a single."
    ),
    GlossaryEntry(
      term: "Singles & Pairs",
      definition:
        "A family of hands made only of singles and pairs. Jokers are not allowed and you cannot call discards, so plan these early."
    ),
    GlossaryEntry(
      term: "Soap",
      definition:
        "Nickname for the White Dragon, which also serves as the zero in year hands such as 2026."
    ),
    GlossaryEntry(
      term: "Wall",
      definition:
        "The stacks of face-down tiles that players draw from."
    ),
    GlossaryEntry(
      term: "Wall game",
      definition:
        "A hand that ends with no winner because the wall ran out. Usually nobody pays and the deal moves on."
    ),
    GlossaryEntry(
      term: "Wind",
      definition:
        "One of the North, East, West and South honour tiles, four of each."
    ),
  ]
}
