import Foundation

/// Rules quick reference. Original wording; table procedures are described as "the standard way".
enum LearnRules {
  static let topic = LearnTopic(
    id: "rules",
    title: "Rules quick reference",
    summary: "The whole game on one page: the goal, the Charleston, your turn, calling and paying.",
    symbol: "book",
    sections: [
      LearnSection(
        id: "goal", heading: "The goal",
        blocks: [
          .paragraph(
            "Everyone races to build a hand of exactly 14 tiles that matches one line on the card. The first player to do it calls Mahjong and wins the hand."
          ),
          .paragraph(
            "Each turn you take one tile and let go of one tile, slowly shaping your rack toward a line you picked."
          ),
        ]),
      LearnSection(
        id: "tiles", heading: "The tiles",
        blocks: [
          .paragraph(
            "A set has 152 tiles. Here is the short version; the Tiles topic has the details."
          ),
          .bullets([
            "Three suits (Cracks, Bams, Dots) numbered 1 to 9, four copies of each: 108 tiles.",
            "Four winds (North, East, West, South), four copies each: 16 tiles.",
            "Three dragons (Red, Green and White), four copies each: 12 tiles.",
            "8 flowers. Any flower can stand in for any other.",
            "8 jokers, which are wild with a few limits.",
          ]),
          .paragraph(
            "The White Dragon is nicknamed Soap. It is also used as the zero in year hands such as 2026."
          ),
        ]),
      LearnSection(
        id: "card", heading: "The card",
        blocks: [
          .paragraph(
            "The card lists every hand you are allowed to win with. Lines are grouped into families, such as a run of numbers or a set of winds and dragons."
          ),
          .bullets([
            "Colours are suits: the same colour means the same suit, and different colours mean different suits. You choose which real suit goes with which colour.",
            "X means an Exposed hand: you may call discards to build groups. C means a Concealed hand: you may only call the very last tile.",
            "The number beside each line is its points.",
          ]),
          .paragraph("The Reading a card topic walks through all of this slowly."),
        ]),
      LearnSection(
        id: "setup", heading: "Setup and the deal",
        blocks: [
          .paragraph(
            "Tiles are shuffled, built into walls and dealt. In the standard way, East (the dealer) starts with 14 tiles and everyone else starts with 13."
          ),
          .paragraph(
            "East begins by discarding one tile. After that, play moves to the right (counter-clockwise)."
          ),
          .note("At a real table, the tiles live in your rack, hidden from the others."),
        ]),
      LearnSection(
        id: "charleston", heading: "The Charleston",
        blocks: [
          .paragraph(
            "Before play starts, players swap unwanted tiles in a ritual called the Charleston. Here is the standard way. Pass face down, and choose your tiles before you look at what you receive."
          ),
          .paragraph("First Charleston (everyone takes part):"),
          .steps([
            "→ Pass 3 tiles to the right.",
            "↔ Pass 3 tiles across the table.",
            "← Pass 3 tiles to the left. This last pass may be a blind pass: you may hand on 1 to 3 of the tiles you just received without looking at them.",
          ]),
          .paragraph(
            "After the first Charleston, any player may call a stop. If nobody does, the table goes on to the second Charleston, which runs in the opposite order:"
          ),
          .steps([
            "← Pass 3 tiles to the left.",
            "↔ Pass 3 tiles across.",
            "→ Pass 3 tiles to the right. Again, this last pass may be a blind pass.",
          ]),
          .paragraph(
            "Finally comes an optional courtesy pass ↔ across: you and the player opposite agree to swap 0 to 3 tiles. If you disagree, the smaller number wins."
          ),
          .bullets([
            "Jokers can never be passed. Keep them.",
            "Keep two or three possible hands in mind during the Charleston and decide afterward.",
          ]),
        ]),
      LearnSection(
        id: "turn", heading: "Your turn",
        blocks: [
          .steps([
            "Draw a tile from the wall (unless you have just called a discard).",
            "If you like, swap a joker out of an exposure on the table using the matching natural tile from your rack (see Jokers).",
            "Discard one tile face up and say its name out loud so everyone can hear.",
          ]),
          .paragraph(
            "After your discard you should always hold 13 tiles, counting any groups you have exposed. A winning hand is 14."
          ),
        ]),
      LearnSection(
        id: "calling", heading: "Calling a discard",
        blocks: [
          .paragraph(
            "When someone discards a tile you need, you can call it before the next player draws."
          ),
          .bullets([
            "You can call a discard to complete a group of three or more (pung, kong, quint or sextet). You must then show that group, face up, in front of your rack.",
            "A single or a pair can only be called if that tile finishes your hand with Mahjong.",
            "Mahjong beats any other call. If two players want the same tile, the one whose turn would come first goes first.",
            "In a Concealed hand you may only call the last tile that makes Mahjong, so you never show anything early.",
          ]),
          .note("Once you expose a group, it has to fit the line you end up playing."),
        ]),
      LearnSection(
        id: "jokers", heading: "Jokers",
        blocks: [
          .paragraph(
            "A joker can stand in for any tile, but only inside a group of three or more. Jokers never go in singles or pairs, so a hand made of only singles and pairs is always played without them."
          ),
          .paragraph(
            "Joker exchange: on your turn, if an exposure (yours or someone else's) has a joker standing in for a natural tile and you hold that exact tile, you may swap it in and take the joker for yourself."
          ),
          .bullets([
            "Jokers cannot be passed in the Charleston.",
            "Throwing a joker away is nearly always a mistake.",
          ]),
        ]),
      LearnSection(
        id: "paying", heading: "Winning and paying",
        blocks: [
          .paragraph(
            "The winner collects points from the other players. Who pays what depends on how the winning tile arrived."
          ),
          .bullets([
            "Won on someone's discard: the player who threw it pays double. The others pay the base amount.",
            "Self-pick (you drew the winning tile yourself): everyone pays double.",
            "Jokerless (no jokers anywhere in your hand): all amounts double again. Hands that cannot use jokers anyway earn no extra bonus.",
          ]),
          .paragraph(
            "Worked example: A wins a 25-point hand. Each row shows who gains and who loses."
          ),
          .table(
            header: ["How A won", "A", "B", "C", "D"],
            rows: [
              ["B discards", "+100", "−50", "−25", "−25"],
              ["Self-pick", "+150", "−50", "−50", "−50"],
              ["B discards, jokerless", "+200", "−100", "−50", "−50"],
              ["Self-pick, jokerless", "+300", "−100", "−100", "−100"],
              [
                "B discards, jokerless, but the hand could not use jokers anyway", "+100", "−50",
                "−25", "−25",
              ],
            ]),
          .note(
            "With only three players, B discarding to A on a 25-point hand gives +75 to A, −50 to B and −25 to C."
          ),
        ]),
      LearnSection(
        id: "dead", heading: "Dead hands and wall games",
        blocks: [
          .paragraph(
            "A hand is dead when it can no longer be made legally, for example after exposing the wrong groups or holding the wrong number of tiles. A player with a dead hand stops trying to win but still pays the winner."
          ),
          .paragraph(
            "A wall game happens when the wall runs out and nobody has won. In the standard way nobody pays anything, the tiles are reshuffled and the deal moves on."
          ),
        ]),
      LearnSection(
        id: "closing", heading: "Before you play",
        blocks: [
          .note(
            "Your card's printed rules and your table's house rules always win. Everything here is the standard way, so check with your group before the first hand."
          )
        ]),
    ])
}
