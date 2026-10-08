import Foundation

/// The app's compact hand notation, with examples that the parser accepts.
enum LearnNotation {
  static let topic = LearnTopic(
    id: "notation",
    title: "Notation guide",
    summary: "The short text format Mahjong Mania uses to describe a hand, one line per hand.",
    symbol: "textformat.abc",
    sections: [
      LearnSection(
        id: "anatomy", heading: "Anatomy of a line",
        blocks: [
          .paragraph(
            "Every hand is one line of text with parts separated by semicolons: the tiles, then the points, then X or C, then an optional name, then an optional flag."
          ),
          .example(
            notation: "FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs",
            caption:
              "Tiles, then 25 points, then X (exposed), then the name. The tiles must add up to exactly 14."
          ),
          .paragraph("Tile groups are separated by spaces."),
        ]),
      LearnSection(
        id: "groups", heading: "Groups and runs",
        blocks: [
          .paragraph(
            "Write a tile as many times as you need it. A run of the same character becomes one group: 22 is a pair, 222 a pung, 2222 a kong. Different characters side by side are separate singles."
          ),
          .bullets([
            "2222 is a kong of 2s.",
            "2026 is four singles: 2, 0, 2 and 6.",
            "11222 is a pair of 1s followed by a pung of 2s.",
            "F is a flower, N E W S are the winds, R and G are the red and green dragons.",
          ]),
          .example(
            notation: "11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift",
            caption: "A staircase: a pair, a pung, a kong, a pung, a pair, all in one suit."),
        ]),
      LearnSection(
        id: "suits", heading: "Suits: variables and fixed",
        blocks: [
          .paragraph(
            "Number tiles need a suit, written after a slash. The letters x, y and z are variables: each stands for a suit of your choosing, and different letters always mean different suits. The letters c, b and d are fixed: Cracks, Bams and Dots."
          ),
          .example(
            notation: "FFFF 2468/x 222/y 888/z ; 25 ; X ; Even Spread",
            caption: "Three different suits: x, y and z must all be different."),
          .example(
            notation: "FFFF 1111/c 9999/d 55/b ; 25 ; X ; Fixed Odd Ends",
            caption: "Fixed suits: 1s in Cracks, 9s in Dots and 5s in Bams, no choice involved."),
          .note("The suit after a slash covers every number tile in that group of characters."),
        ]),
      LearnSection(
        id: "dragons", heading: "Dragons and Soap",
        blocks: [
          .paragraph(
            "The letter D means the dragon that matches the suit written after it: D/x is the dragon that goes with suit x. Fixed suits give fixed dragons, so D/c is the Red Dragon."
          ),
          .example(
            notation: "NNN SSS DDDD/x DDDD/y ; 25 ; X ; North South Dragons",
            caption: "Two kongs of matching dragons, one for each of two different suits."),
          .paragraph(
            "The digit 0 is Soap, the White Dragon, and never takes a suit. It is how years like 2026 are written."
          ),
          .example(
            notation: "2222/x 000 222/y 6666/z ; 25 ; X ; Soap Year",
            caption: "Three Soaps (000) sit between a kong of 2s, a pung of 2s and a kong of 6s."),
        ]),
      LearnSection(
        id: "ops", heading: "Plus and equals",
        blocks: [
          .paragraph(
            "The symbols + and = are only decoration so that addition hands look like sums on a card. The app skips over them when it works out the tiles."
          ),
          .example(
            notation: "FF 3333/x + 4444/y = 7777/z ; 25 ; X ; Three Plus Four",
            caption: "3 plus 4 equals 7, each in its own suit."),
        ]),
      LearnSection(
        id: "variants", heading: "Alternatives with a bar",
        blocks: [
          .paragraph(
            "When a line can be completed in more than one way, separate the ways with a vertical bar. Each alternative must be a full 14 tiles."
          ),
          .example(
            notation: "NNNNN EEEE 11111/x | SSSSS WWWW 11111/x ; 40 ; X ; Wind Quints ; shift",
            caption: "Either North quint with East kong, or South quint with West kong."),
        ]),
      LearnSection(
        id: "shift", heading: "Shift flags",
        blocks: [
          .paragraph(
            "Add shift at the end to say that the numbers may slide up or down together (any consecutive or like numbers). The written digits are just an example. Add shift2 to slide only in steps of two, which keeps odd numbers odd and even numbers even."
          ),
          .example(
            notation: "FFF 1111/x 2222/y 333/z ; 25 ; X ; Three Suit Run ; shift",
            caption: "Runs from 1-2-3 up to 7-8-9."),
          .example(
            notation: "111/x 333/x 555/x 777/x FF ; 30 ; X ; Odd Pungs ; shift2",
            caption: "Odd stays odd: 1-3-5-7 can become 3-5-7-9, but not 2-4-6-8."),
        ]),
      LearnSection(
        id: "xc", heading: "X, C and points",
        blocks: [
          .paragraph(
            "The second field is the points, from 1 to 500. The third is X for an exposed hand or C for a concealed one."
          ),
          .example(
            notation: "2026/x 2026/y 2026/z DD/x ; 75 ; C ; Triple Year",
            caption: "Concealed and worth 75, so the line ends with C."),
          .example(
            notation: "22/x + 55/x = 77/x 22/y + 55/y = 77/y FF ; 50 ; C ; Double Sum",
            caption: "A concealed hand made entirely of pairs."),
        ]),
      LearnSection(
        id: "files", heading: "Card files",
        blocks: [
          .paragraph(
            "A whole card is a text file with one hand per line. A line starting with ! gives the card's name, # starts a new section, and // starts a comment."
          ),
          .bullets([
            "! My Card names the card.",
            "# Evens starts a section called Evens.",
            "Blank lines are ignored.",
          ]),
          .note("Enter hands from a card you own. Please do not publicly share copyrighted cards."),
        ]),
    ])
}
