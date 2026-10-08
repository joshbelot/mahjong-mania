import Foundation

/// Every tile type, with nicknames and counts.
enum LearnTiles {
  static let topic = LearnTopic(
    id: "tiles",
    title: "Tiles",
    summary: "What is in the set of 152, what the tiles are called and how many of each there are.",
    symbol: "square.grid.3x3",
    sections: [
      LearnSection(
        id: "suits", heading: "The three suits",
        blocks: [
          .paragraph(
            "Each suit has the numbers 1 to 9 and four copies of every number, so 36 tiles per suit."
          ),
          .table(
            header: ["Suit", "Also called", "Colour", "Copies"],
            rows: [
              ["Cracks", "Craks, Characters", "Red", "36"],
              ["Bams", "Bamboo", "Green", "36"],
              ["Dots", "Circles", "Blue", "36"],
            ]),
          .note("The 1 Bam is traditionally drawn as a bird, so it is easy to spot."),
        ]),
      LearnSection(
        id: "winds", heading: "Winds",
        blocks: [
          .paragraph(
            "North, East, West and South, with four copies of each (16 tiles). They are written N, E, W and S on a card."
          )
        ]),
      LearnSection(
        id: "dragons", heading: "Dragons",
        blocks: [
          .paragraph("There are three dragons, four copies each (12 tiles)."),
          .table(
            header: ["Dragon", "Nickname", "Goes with"],
            rows: [
              ["Red Dragon", "Red", "Cracks"],
              ["Green Dragon", "Green", "Bams"],
              ["White Dragon", "Soap, or zero", "Dots"],
            ]),
          .paragraph(
            "A dragon shown in a suit's colour on the card means the dragon that goes with that suit. That is called the matching dragon."
          ),
          .paragraph(
            "Soap does double duty. In year hands it is the zero (so a 2026 hand uses one Soap), and it also serves as the ordinary White Dragon."
          ),
        ]),
      LearnSection(
        id: "flowers", heading: "Flowers",
        blocks: [
          .paragraph(
            "There are 8 flowers. They look different (flowers and seasons) but all of them count as the same tile, so any flower fits any flower slot."
          )
        ]),
      LearnSection(
        id: "jokers", heading: "Jokers",
        blocks: [
          .paragraph(
            "There are 8 jokers. A joker can stand in for any tile, but only inside groups of three or more tiles. Never use one in a single or a pair."
          )
        ]),
      LearnSection(
        id: "total", heading: "The full set",
        blocks: [
          .table(
            header: ["Tile", "Copies each", "Total"],
            rows: [
              ["Cracks 1 to 9", "4", "36"],
              ["Bams 1 to 9", "4", "36"],
              ["Dots 1 to 9", "4", "36"],
              ["Winds (4 kinds)", "4", "16"],
              ["Dragons (3 kinds)", "4", "12"],
              ["Flowers", "8 in all", "8"],
              ["Jokers", "8 in all", "8"],
              ["Everything", "All of the above", "152"],
            ]),
          .note(
            "Knowing there are only four of each ordinary tile helps you tell when a hand you wanted is impossible, because the tiles you need are all gone."
          ),
        ]),
    ])
}
