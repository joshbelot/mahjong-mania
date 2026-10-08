import Foundation

/// How to read a card.
enum LearnReading {
  static let topic = LearnTopic(
    id: "reading",
    title: "Reading a card",
    summary: "Families, colours, X and C, points, and why some hands have to be chosen early.",
    symbol: "list.bullet.rectangle",
    sections: [
      LearnSection(
        id: "families", heading: "Families",
        blocks: [
          .paragraph(
            "The card is split into sections, called families. Each family has a theme, such as even numbers, a run of consecutive numbers, or winds and dragons. Hands in a family look alike, so tiles that help one hand often help its neighbours too."
          ),
          .paragraph(
            "Early in a game, think in families rather than single hands. If your rack leans toward odd numbers, every line in the odd family is still on the table."
          ),
        ]),
      LearnSection(
        id: "colours", heading: "Colours mean suits",
        blocks: [
          .paragraph(
            "Lines are printed in several colours. A colour does not tell you which real suit to use. It only tells you which groups share a suit."
          ),
          .bullets([
            "Same colour: same suit.",
            "Different colours: different suits.",
            "Which actual suit gets which colour is up to you.",
          ]),
          .example(
            notation: "FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs",
            caption:
              "The 2026 is one suit, and both kongs share a second suit. The two suits must differ."
          ),
        ]),
      LearnSection(
        id: "xc", heading: "X and C",
        blocks: [
          .bullets([
            "X: Exposed. You may call discards to complete groups of three or more and show them.",
            "C: Concealed. You may not show anything until you win. You may call only the final tile.",
          ]),
          .paragraph(
            "Concealed hands are worth more because they are harder, and a single exposure kills them."
          ),
          .example(
            notation: "FF NEWS 2026/x 2026/y ; 50 ; C ; Compass Year",
            caption: "A concealed hand. Every group stays hidden in your rack until Mahjong."),
        ]),
      LearnSection(
        id: "points", heading: "Points",
        blocks: [
          .paragraph(
            "The number beside a line is its base value. Harder hands, such as concealed ones or ones made of pairs, are worth more. Payments are multiples of that number, as described in Winning and paying."
          )
        ]),
      LearnSection(
        id: "consecutive", heading: "Any consecutive and like numbers",
        blocks: [
          .paragraph(
            "Some lines are printed with a note like any consecutive numbers or any like numbers. The digits on the card are only an example. You may slide all the numbers up or down together, provided they all stay between 1 and 9."
          ),
          .example(
            notation: "11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift",
            caption:
              "Printed as 1 to 5, but 2 to 6, 3 to 7, 4 to 8 and 5 to 9 are legal too."),
          .paragraph(
            "Like numbers means the same number in different suits, for example 4s in all three suits."
          ),
        ]),
      LearnSection(
        id: "singles", heading: "Singles and Pairs",
        blocks: [
          .paragraph(
            "This family is made up of single tiles and pairs, with no group of three or more. That has two big consequences."
          ),
          .bullets([
            "Jokers are not allowed, because they only work in groups of three or more.",
            "You cannot call discards to build it, apart from the tile that wins.",
          ]),
          .paragraph(
            "Because nothing can rescue a weak rack, decide on a Singles and Pairs hand early, ideally during the Charleston."
          ),
          .example(
            notation: "NN EE WW SS 11/x 11/y 11/z ; 50 ; C ; Winds And Likes ; shift",
            caption: "Seven pairs and no joker slots anywhere. It is always concealed."),
        ]),
    ])
}
