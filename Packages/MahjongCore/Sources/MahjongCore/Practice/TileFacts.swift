import Foundation

/// `tileFact` (SPEC §19.1): things a beginner can't read off a tile. Every fact is a short question
/// whose answer is not printed anywhere on the question screen.
enum TileFacts {
  enum Fact: Hashable, Sendable {
    case dragonForSuit(Suit)
    case suitForDragon(Dragon)
    case countSuited(Suit)
    case countWind
    case countDragon
    case zeroTile
    case countFlowers
    case countJokers
    case countWhole
    case jokerPair
    case jokerCharleston
    case jokerSmallest
    case flowersSame
    case nickname(Suit)
    case dealer
    case firstPass
    // House rules (difficulty 3, only with a rule book).
    case blankSet
    case blankSwap
    case secondCharleston
    case courtesy
    case jokerExchange
  }

  // MARK: Pools

  private static let suitsAndDragons: [Fact] =
    Suit.allCases.map { Fact.dragonForSuit($0) } + Dragon.allCases.map { Fact.suitForDragon($0) }
    + Suit.allCases.map { Fact.countSuited($0) } + [.countWind, .countDragon]

  private static let flowersJokersSoap: [Fact] = [
    .zeroTile, .countFlowers, .countJokers, .countWhole, .jokerPair, .jokerCharleston, .jokerSmallest, .flowersSame,
  ]

  private static let nicknamesAndDealing: [Fact] = Suit.allCases.map { Fact.nickname($0) } + [.dealer, .firstPass]

  /// The facts a (difficulty, focus) asks about, without any house rules.
  static func pool(difficulty: Int, focus: Int) -> [Fact] {
    var facts: [Fact]
    switch focus {
    case ExerciseFocus.suitsAndDragons: facts = suitsAndDragons
    case ExerciseFocus.flowersJokersSoap: facts = flowersJokersSoap
    default: facts = suitsAndDragons + flowersJokersSoap
    }
    if difficulty >= 2 && focus == 0 { facts += nicknamesAndDealing }
    return facts
  }

  /// The house-rule facts that apply to `rules` (blanks only when that rule is on).
  static func houseFacts(_ rules: RuleSet?) -> [Fact] {
    guard let rules else { return [] }
    func rule(_ id: String) -> HouseRule? { rules.rules.first { $0.id == id } }
    var facts: [Fact] = []
    if rule(RuleID.blanks)?.isEnabled == true { facts += [.blankSet, .blankSwap] }
    if rule(RuleID.charlestonSecond) != nil { facts.append(.secondCharleston) }
    if rule(RuleID.courtesy) != nil { facts.append(.courtesy) }
    if rule(RuleID.jokerExchange) != nil { facts.append(.jokerExchange) }
    return facts
  }

  /// How many different questions a lesson part can ask (so a lesson can avoid repeating one).
  static func poolSize(difficulty: Int, focus: Int) -> Int { pool(difficulty: difficulty, focus: focus).count }

  /// Which fact a seed asks about, before any house rules are considered.
  static func factIndex(seed: UInt64, difficulty: Int, focus: Int) -> Int {
    Int(seed % UInt64(max(1, poolSize(difficulty: difficulty, focus: focus))))
  }

  // MARK: Building

  private struct Pick {
    var prompt: String
    var correct: Choice
    var wrong: [Choice]
    var answer: String
    var explanation: String
    var hint: String
  }

  static func make(_ id: ExerciseID, rules: RuleSet?, rng: inout SeededRandom) -> Built {
    var facts = pool(difficulty: id.difficulty, focus: id.focus)
    let index = factIndex(seed: id.seed, difficulty: id.difficulty, focus: id.focus)
    if id.difficulty >= 3 && id.focus == 0 {
      let house = houseFacts(rules)
      // Half of the hard questions come from the rule book when it has anything to ask about.
      if !house.isEmpty && id.seed % 2 == 0 { facts = house }
    }
    let fact = facts[index % facts.count]
    let pick = build(fact, rules: rules, rng: &rng)
    var choices = [pick.correct] + pick.wrong
    let numbers = choices.allSatisfy { if case .number = $0 { return true } else { return false } }
    let yesNo = choices.allSatisfy { if case .yesNo = $0 { return true } else { return false } }
    if numbers {
      choices.sort { lhs, rhs in
        if case .number(let a) = lhs, case .number(let b) = rhs { return a < b }
        return false
      }
    } else if yesNo {
      choices = [.yesNo(true), .yesNo(false)]
    } else {
      choices = rng.shuffled(choices)
    }
    let correctIndex = choices.firstIndex(of: pick.correct) ?? 0
    var exercise = Exercise(
      id: id, prompt: pick.prompt, choices: choices,
      key: .choices(correct: [correctIndex], answer: pick.answer, explanation: pick.explanation))
    exercise.hintText = pick.hint
    return Built(exercise: exercise, ok: true)
  }

  private static func text(_ value: String) -> Choice { .text(value) }

  private static func build(_ fact: Fact, rules: RuleSet?, rng: inout SeededRandom) -> Pick {
    switch fact {
    case .dragonForSuit(let suit):
      let right = Tile.matchingDragon(suit)
      let others = Dragon.allCases.map { Tile.dragon($0) }.filter { $0 != right }
      return Pick(
        prompt: "Which dragon goes with \(suit.plainName)?", correct: text(right.name),
        wrong: others.map { text($0.name) } + [text("North")], answer: right.name,
        explanation: "The \(right.name) goes with the \(suit.plainName). Red goes with Cracks, Green with Bams and Soap with Dots.",
        hint: "Each dragon is named for the suit it goes with: red for Cracks, green for Bams, white for Dots.")
    case .suitForDragon(let dragon):
      let tile = Tile.dragon(dragon)
      let suit = Suit.allCases.first { Tile.matchingDragon($0) == tile } ?? .dots
      let others = Suit.allCases.filter { $0 != suit }.map { text($0.plainName) }
      return Pick(
        prompt: "Which suit does the \(tile.name) go with?", correct: text(suit.plainName),
        wrong: others + [text("Winds")], answer: suit.plainName,
        explanation: "The \(tile.name) goes with the \(suit.plainName). Red goes with Cracks, Green with Bams and Soap with Dots.",
        hint: "Think of the dragon's colour: red for Cracks, green for Bams, white (Soap) for Dots.")
    case .countSuited(let suit):
      let value = rng.element(of: [1, 2, 3, 5, 6, 7, 8, 9]) ?? 5
      return count(of: "\(value) \(suit.plainName.dropLast())s", copies: 4)
    case .countWind:
      let wind = rng.element(of: [Wind.north, .east, .west, .south]) ?? .east
      return count(of: "\(Tile.wind(wind).name) Winds", copies: 4)
    case .countDragon:
      let dragon = rng.element(of: [Dragon.red, .green]) ?? .red
      return count(of: "\(Tile.dragon(dragon).name)s", copies: 4)
    case .countFlowers:
      return count(of: "Flowers", copies: 8, subject: "Flowers")
    case .countJokers:
      return count(of: "Jokers", copies: 8, subject: "Jokers")
    case .countWhole:
      return Pick(
        prompt: "How many tiles are in a whole set?", correct: .number(152),
        wrong: [.number(136), .number(144), .number(160)], answer: "152",
        explanation:
          "A set has 152 tiles: 108 in the three suits (4 of each of 27 tiles), 28 Winds and Dragons (4 of each of 7), 8 Flowers and 8 Jokers.",
        hint: "Count it up: three suits of 36, plus the honours, flowers and jokers.")
    case .zeroTile:
      return Pick(
        prompt: "In a year hand like 2026, which tile is the 0?", correct: .tile(.dragon(.white)),
        wrong: [.tile(.flower), .tile(.joker), .tile(.dragon(.red))], answer: Tile.dragon(.white).name,
        explanation: "Soap, the White Dragon, stands in for the 0 in year hands.",
        hint: "It's a dragon, and the blank-looking one.")
    case .jokerPair:
      return Pick(
        prompt: "Can a joker be part of a pair?", correct: .yesNo(false), wrong: [.yesNo(true)], answer: "No",
        explanation: "Jokers only join sets of three or more tiles. They can never be in a pair or a single.",
        hint: "Jokers need at least three tiles in the set.")
    case .jokerCharleston:
      return Pick(
        prompt: "Can you pass a joker in the Charleston?", correct: .yesNo(false), wrong: [.yesNo(true)],
        answer: "No", explanation: "Jokers are never passed. You always keep them.",
        hint: "Jokers are too valuable to give away, so the rules don't allow it.")
    case .jokerSmallest:
      return Pick(
        prompt: "What's the smallest set a joker can join?", correct: text("Pung (3 tiles)"),
        wrong: [text("Single (1 tile)"), text("Pair (2 tiles)"), text("Kong (4 tiles)")], answer: "Pung (3 tiles)",
        explanation: "A joker can stand in for a tile in a Pung (3), a Kong (4), a Quint (5) or a Sextet (6), but never a Single or a Pair.",
        hint: "Not a single and not a pair.")
    case .flowersSame:
      return Pick(
        prompt: "Are all Flowers the same for making a hand?", correct: .yesNo(true), wrong: [.yesNo(false)],
        answer: "Yes",
        explanation: "All eight Flowers count as the same tile, whatever picture they show.",
        hint: "The pictures are only decoration.")
    case .nickname(let suit):
      let names: [Suit: String] = [.bams: "Bamboo", .cracks: "Characters", .dots: "Circles"]
      let right = names[suit] ?? "Circles"
      let wrong = names.values.filter { $0 != right }.sorted().map { text($0) } + [text("Dragons")]
      return Pick(
        prompt: "\(suit.plainName) are also called\u{2026}", correct: text(right), wrong: wrong, answer: right,
        explanation: "\(suit.plainName) are also called \(right). Bams are Bamboo, Cracks are Characters and Dots are Circles.",
        hint: "Bams, Cracks and Dots each have a longer name.")
    case .dealer:
      return Pick(
        prompt: "Who starts the hand with 14 tiles?", correct: text("East"),
        wrong: [text("South"), text("West"), text("North")], answer: "East",
        explanation: "East is the dealer. East gets 14 tiles and discards first; everyone else starts with 13.",
        hint: "The dealer is the first wind.")
    case .firstPass:
      return Pick(
        prompt: "Which way is the first Charleston pass?", correct: text("To the right"),
        wrong: [text("To the left"), text("Across the table"), text("Diagonally")], answer: "To the right",
        explanation: "The first Charleston goes right, then across, then left.",
        hint: "Right, across, left: the order of the first Charleston.")
    case .blankSet:
      let blanks = rules?.rules.first { $0.id == RuleID.blanks }?.blanks?.count ?? 6
      let whole = 152 + blanks
      return Pick(
        prompt: "With your table's blanks, how many tiles are in the whole set?", correct: .number(whole),
        wrong: [152, 152 + 2, 152 + 4, 152 + 6].filter { $0 != whole }.prefix(3).map { .number($0) },
        answer: "\(whole)", explanation: "A normal set has 152 tiles. Your table adds \(blanks) blanks, so \(whole).",
        hint: "Start from 152 and add the blanks your rule book lists.")
    case .blankSwap:
      return Pick(
        prompt: "What can you swap a blank for?", correct: text("A discarded tile"),
        wrong: [text("A tile from the wall"), text("A tile in another player's rack"), text("Nothing, ever")],
        answer: "A discarded tile",
        explanation: "At a table that plays with blanks, a blank can be swapped for a tile that has been discarded.",
        hint: "Think about which tiles are lying face up.")
    case .secondCharleston:
      let on = rules?.rules.first { $0.id == RuleID.charlestonSecond }?.isEnabled ?? true
      return Pick(
        prompt: "In your rule book, is there a second Charleston?", correct: .yesNo(on), wrong: [.yesNo(!on)],
        answer: on ? "Yes" : "No",
        explanation: on
          ? "Your rule book has the second Charleston (left, across, right) switched on."
          : "Your rule book has the second Charleston switched off, so your table stops after the first.",
        hint: "Check House rules in the Game tab.")
    case .courtesy:
      let on = rules?.rules.first { $0.id == RuleID.courtesy }?.isEnabled ?? true
      return Pick(
        prompt: "In your rule book, do you play the courtesy pass?", correct: .yesNo(on), wrong: [.yesNo(!on)],
        answer: on ? "Yes" : "No",
        explanation: on
          ? "Your rule book has the courtesy pass switched on: you and the player across may swap up to 3 tiles."
          : "Your rule book has the courtesy pass switched off.",
        hint: "Check House rules in the Game tab.")
    case .jokerExchange:
      let on = rules?.rules.first { $0.id == RuleID.jokerExchange }?.isEnabled ?? true
      return Pick(
        prompt: "In your rule book, may you swap a real tile for a joker in an exposed set?", correct: .yesNo(on),
        wrong: [.yesNo(!on)], answer: on ? "Yes" : "No",
        explanation: on
          ? "Your rule book has joker exchange switched on."
          : "Your rule book has joker exchange switched off.",
        hint: "Check House rules in the Game tab.")
    }
  }

  /// "How many 7 Bams are in a set?" with the right number and three wrong ones.
  private static func count(of name: String, copies: Int, subject: String? = nil) -> Pick {
    let wrong = [2, 3, 4, 6, 8, 9, 12].filter { $0 != copies }
    let near = wrong.sorted { abs($0 - copies) < abs($1 - copies) }.prefix(3)
    return Pick(
      prompt: "How many \(name) are in a set?", correct: .number(copies), wrong: near.map { .number($0) },
      answer: "\(copies)",
      explanation: copies == 8
        ? "A set has 8 \(subject ?? name)."
        : "A set has 4 of every suit, wind and dragon tile.",
      hint: copies == 8 ? "Flowers and Jokers come in eights." : "Every suit, wind and dragon tile comes in fours.")
  }
}
