import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let seats = ["Bea", "Cy", "Alex", "Dee"]
private let names = ["Bea": "Bea", "Cy": "Cy", "Alex": "Alex", "Dee": "Dee"]

private func explain(
  _ input: MahjongInput, seats seatIDs: [String] = seats, rules: RuleSet = .standard, coach: Bool
) -> String {
  let payments = Scoring.payments(for: .mahjong(input), seats: seatIDs, rules: rules)
  return PaymentExplanation.text(
    input: input, seats: seatIDs, payments: payments, rules: rules, names: names, coach: coach)
}

struct PaymentExplanationTests {
  @Test func discardOffAndPeekAreOneLine() {
    let input = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 25)
    #expect(explain(input, coach: false) == "Cy pays 50 (threw it) \u{00B7} others pay 25")
  }

  @Test func discardCoachMatchesTheSpecExample() {
    let input = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 25)
    #expect(
      explain(input, coach: true)
        == "Base 25. Cy threw the winning tile, so Cy pays double (50). Everyone else pays the base (25). Bea collects 100."
    )
  }

  @Test func selfPick() {
    let input = MahjongInput(winnerID: "Bea", basePoints: 25)
    #expect(explain(input, coach: false) == "Others pay 50 (self-pick)")
    #expect(
      explain(input, coach: true)
        == "Base 25. Bea drew the winning tile, so everyone else pays double (50). Bea collects 150.")
  }

  @Test func jokerlessDoublesEveryAmount() {
    let discard = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 25, jokerless: true)
    #expect(
      explain(discard, coach: false)
        == "Cy pays 100 (threw it) \u{00B7} others pay 50 \u{00B7} jokerless \u{00D7}2")
    #expect(
      explain(discard, coach: true)
        == "Base 25. Jokerless, so every payment is multiplied by 2. Cy threw the winning tile, so Cy pays double (100). Everyone else pays the base (50). Bea collects 200."
    )
    let selfPick = MahjongInput(winnerID: "Bea", basePoints: 25, jokerless: true)
    #expect(explain(selfPick, coach: false) == "Others pay 100 (self-pick) \u{00B7} jokerless \u{00D7}2")
  }

  @Test func jokerlessOnASinglesAndPairsLineIsNotMentionedWhenThereIsNoBonus() {
    let input = MahjongInput(
      winnerID: "Bea", discarderID: "Cy", basePoints: 25, jokerless: true, lineHasNoJokerGroups: true)
    #expect(explain(input, coach: false) == "Cy pays 50 (threw it) \u{00B7} others pay 25")
    var rules = RuleSet.standard
    rules.jokerlessBonusForNoJokerLines = true
    #expect(
      explain(input, rules: rules, coach: false)
        == "Cy pays 100 (threw it) \u{00B7} others pay 50 \u{00B7} jokerless \u{00D7}2")
  }

  @Test func threePlayersAndCustomMultipliers() {
    let threeSeats = ["Bea", "Cy", "Alex"]
    var rules = RuleSet.standard
    rules.discarderMultiplier = 3
    rules.othersOnDiscardMultiplier = 2
    let input = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 10)
    #expect(
      explain(input, seats: threeSeats, rules: rules, coach: true)
        == "Base 10. Cy threw the winning tile, so Cy pays triple (30). Everyone else pays double (20). Bea collects 50."
    )
  }

  @Test func multiplierWords() {
    #expect(PaymentExplanation.word(1) == "the base")
    #expect(PaymentExplanation.word(2) == "double")
    #expect(PaymentExplanation.word(3) == "triple")
    #expect(PaymentExplanation.word(4) == "quadruple")
    #expect(PaymentExplanation.word(5) == "\u{00D7}5")
  }
}
