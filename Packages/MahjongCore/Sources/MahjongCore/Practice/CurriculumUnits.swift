import Foundation

extension Curriculum {
  private static func lesson(
    _ unit: Int, _ number: Int, _ title: String, count: Int, intro: String, _ parts: [LessonPart]
  ) -> LessonSpec {
    LessonSpec(id: "u\(unit)l\(number)", unit: unit, kind: .lesson, title: title, intro: intro, count: count, parts: parts)
  }

  private static func unit(
    _ id: Int, _ title: String, _ summary: String, count: Int, review: Bool = true, lessons: [LessonSpec]
  ) -> UnitSpec {
    UnitSpec(
      id: id, title: title, summary: summary, lessons: lessons,
      review: review
        ? LessonSpec(
          id: "u\(id)r", unit: id, kind: .review, title: "Review",
          intro: "A mix of things you've practised, and any you missed lately.", count: reviewCount, parts: [])
        : nil,
      checkpoint: LessonSpec(
        id: "u\(id)c", unit: id, kind: .checkpoint, title: "Checkpoint",
        intro: "Show what you know from this unit. Get \(checkpointPassMark) of \(checkpointCount) right to move on.",
        count: checkpointCount, parts: []))
  }

  public static let units: [UnitSpec] = [
    unit(
      1, "Meet the tiles", "The suits, winds, dragons, flowers and jokers.", count: 8, review: false,
      lessons: [
        lesson(
          1, 1, "Suits and dragons", count: 8,
          intro: "Three suits have the numbers 1 to 9: Cracks (characters, in red), Bams (bamboo, in green) and Dots (circles, in blue). Each suit has a matching dragon: Red goes with Cracks, Green with Bams and Soap, the White Dragon, with Dots.",
          [LessonPart([.tileFact], 1, focus: ExerciseFocus.suitsAndDragons)]),
        lesson(
          1, 2, "Flowers, jokers and Soap", count: 8,
          intro: "A set has 152 tiles. Eight Flowers all count as one tile, and eight Jokers stand in for other tiles, but only in sets of three or more. Soap is the White Dragon, and it is also the zero in year hands.",
          [LessonPart([.tileFact], 1, focus: ExerciseFocus.flowersJokersSoap)]),
        lesson(
          1, 3, "Mixed", count: 8,
          intro: "Everything about the tiles together, plus a few more facts: nicknames for the suits and how the deal starts. Take your time; speed doesn't matter.",
          [LessonPart([.tileFact], 2)]),
      ]),
    unit(
      2, "Read the card", "Sets, colours and the two kinds of hand.", count: 8, review: false,
      lessons: [
        lesson(
          2, 1, "Sets", count: 8,
          intro: "Hands are made of groups. Two the same is a Pair, three a Pung, four a Kong, five a Quint, and six a Sextet. A joker counts as the tile it stands in for, so count it too.",
          [LessonPart([.groupName], 2)]),
        lesson(
          2, 2, "Colours mean suits", count: 8,
          intro: "On the card, each colour is a suit. Different colours must be different suits, but which suit is up to you.",
          [
            LessonPart([.matchesLine], 1, focus: ExerciseFocus.colours),
            LessonPart([.matchesLine], 2, focus: ExerciseFocus.colours),
          ]),
        lesson(
          2, 3, "Exposed vs concealed", count: 8,
          intro: "An X hand lets you call discards and show sets. A C hand is concealed: you can only call the very last tile.",
          [
            LessonPart([.matchesLine], 1, focus: ExerciseFocus.exposedConcealed),
            LessonPart([.matchesLine], 2, focus: ExerciseFocus.exposedConcealed),
          ]),
        lesson(
          2, 4, "Which hand is this?", count: 8,
          intro: "Look at a finished hand and find it on the card.", [LessonPart([.whichHand], 1)]),
      ]),
    unit(
      3, "Jokers", "Where a joker may go, and where it may not.", count: 8,
      lessons: [
        lesson(
          3, 1, "Jokers in sets", count: 8,
          intro: "A joker counts as whichever tile the group needs. Count it as part of the group.",
          [LessonPart([.groupName], 2), LessonPart([.groupName], 3)]),
        lesson(
          3, 2, "Is it legal?", count: 8,
          intro: "Jokers may only stand in groups of three or more. Never in a pair or a single.",
          [LessonPart([.jokerLegal], 1), LessonPart([.jokerLegal], 2), LessonPart([.jokerLegal], 3)]),
        lesson(
          3, 3, "Spot the hand", count: 8,
          intro: "Jokers can hide in a hand. Look at the tiles around them.", [LessonPart([.whichHand], 2)]),
      ]),
    unit(
      4, "How close am I?", "Counting the tiles a hand still needs.", count: 8,
      lessons: [
        lesson(
          4, 1, "Counting tiles away", count: 8,
          intro: "A hand is 'N tiles away' when you need N more tiles to finish it. Zero is Mahjong.",
          [LessonPart([.howFar], 1)]),
        lesson(
          4, 2, "A little harder", count: 8, intro: "Some tiles in your rack don't fit. Only count the ones that do.",
          [LessonPart([.howFar], 1), LessonPart([.howFar], 2)]),
        lesson(
          4, 3, "What do I need?", count: 8,
          intro: "Find the tile that gets a hand closer.", [LessonPart([.neededTile], 1)]),
        lesson(
          4, 4, "Closer and closer", count: 8,
          intro: "Mix of counting and finding tiles.",
          [LessonPart([.neededTile], 2), LessonPart([.howFar], 2)]),
      ]),
    unit(
      5, "Choose your hand", "Picking which hand to aim for.", count: 6,
      lessons: [
        lesson(
          5, 1, "Follow your tiles", count: 6,
          intro: "Aim for the hand that already uses most of your tiles.", [LessonPart([.pickHand], 1)]),
        lesson(
          5, 2, "Pick and count", count: 6, intro: "Choose a hand, then check how far away it is.",
          [LessonPart([.pickHand, .howFar], 1)]),
        lesson(
          5, 3, "Closer calls", count: 6, intro: "Now the choices are closer together.",
          [LessonPart([.pickHand], 2)]),
        lesson(
          5, 4, "Mixed choices", count: 6, intro: "A mix of choosing and counting.",
          [LessonPart([.pickHand, .howFar], 2)]),
      ]),
    unit(
      6, "Charleston basics", "Deciding which tiles to keep and which to pass.", count: 6,
      lessons: [
        lesson(
          6, 1, "Pass one", count: 6,
          intro: "In the Charleston you pass tiles you don't need. Start with just one.", [LessonPart([.passOne], 1)]),
        lesson(
          6, 2, "Keep or pass?", count: 6, intro: "Look at one tile at a time and decide.",
          [LessonPart([.keepOrPass], 1)]),
        lesson(
          6, 3, "Fewer spares", count: 6, intro: "Fewer tiles are spare now.",
          [LessonPart([.passOne], 2), LessonPart([.keepOrPass], 2)]),
        lesson(
          6, 4, "One spare", count: 6, intro: "Sometimes only one tile is truly spare.",
          [LessonPart([.passOne], 3), LessonPart([.keepOrPass], 2)]),
      ]),
    unit(
      7, "The whole card", "Choosing from every hand on the card.", count: 5,
      lessons: [
        lesson(
          7, 1, "More choices", count: 5, intro: "Five hands to choose from now.", [LessonPart([.pickHand], 2)]),
        lesson(
          7, 2, "Up a level", count: 5, intro: "A few from the whole card.",
          [LessonPart([.pickHand], 2), LessonPart([.pickHand], 3)]),
        lesson(
          7, 3, "Scan the card", count: 5, intro: "Scan every hand. The tiles point to a few good ones.",
          [LessonPart([.pickHand], 3)]),
        lesson(
          7, 4, "Anything goes", count: 5, intro: "Any deal, any hand.", [LessonPart([.pickHand], 3)]),
      ]),
    unit(
      8, "Real Charlestons", "Passing three tiles like you would at the table.", count: 5,
      lessons: [
        lesson(
          8, 1, "Three tiles", count: 5,
          intro: "Pass three at once. Your two best hands are shown to help.", [LessonPart([.passThree], 1)]),
        lesson(
          8, 2, "No hints", count: 5, intro: "No hands shown now. Pass what none of your best hands use.",
          [LessonPart([.passThree], 2)]),
        lesson(
          8, 3, "Tricky tiles", count: 5, intro: "Some tiles only help your second-best hand.",
          [LessonPart([.passThree], 2), LessonPart([.passThree], 3)]),
        lesson(
          8, 4, "Traps", count: 5, intro: "The obvious pass isn't always the best one.",
          [LessonPart([.passThree], 3)]),
      ]),
    unit(
      9, "At the table", "Calling discards.", count: 6,
      lessons: [
        lesson(
          9, 1, "Call it?", count: 6,
          intro: "You may call a discard to make a set of three or more, or to win. Otherwise let it go.",
          [LessonPart([.callIt], 1)]),
        lesson(
          9, 2, "Calling to win", count: 6, intro: "Sometimes the discard wins the game.",
          [LessonPart([.callIt], 2), LessonPart([.neededTile], 3)]),
        lesson(
          9, 3, "Tough calls", count: 6, intro: "Concealed hands and pairs make it tricky.",
          [LessonPart([.callIt], 3)]),
      ]),
    unit(
      10, "Mastery", "Everything at the hardest level.", count: 8,
      lessons: [
        lesson(
          10, 1, "Tiles and groups", count: 8, intro: "Tiles, sets and card reading, all at the hardest level.",
          [LessonPart([.tileFact, .groupName, .matchesLine], 3)]),
        lesson(
          10, 2, "Jokers and distance", count: 8, intro: "Which hand, which jokers, how far.",
          [LessonPart([.whichHand, .jokerLegal, .howFar, .neededTile], 3)]),
        lesson(
          10, 3, "Choose and pass", count: 8, intro: "Pick a hand and pass the rest.",
          [LessonPart([.pickHand, .passOne, .passThree], 3)]),
        lesson(
          10, 4, "Keep and call", count: 8, intro: "Keep, pass and call.",
          [LessonPart([.keepOrPass, .callIt, .pickHand], 3)]),
        lesson(
          10, 5, "The lot", count: 8, intro: "Every kind of question.",
          [LessonPart(ExerciseType.allCases, 3)]),
      ]),
  ]
}
