import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private func line(_ name: String) -> CardLine {
  guard let found = PracticeCard.card.lines.first(where: { $0.displayName == name }) else {
    preconditionFailure("Practice Card has no line named \(name)")
  }
  return found
}

struct RecordHandModelTests {
  @Test func startsInvalidAndNeedsEveryPart() {
    var draft = RecordHandDraft()
    #expect(!draft.isValid)
    draft.selectWinner("a")
    #expect(!draft.isValid)
    draft.selectHow(.discard)
    draft.points = 25
    #expect(!draft.isValid)  // nobody threw it yet
    draft.discarderID = "b"
    #expect(draft.isValid)
  }

  @Test func theExperiencedPathIsFiveChoices() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")  // 1 winner
    draft.selectHow(.discard)  // 2 Discard
    draft.discarderID = "b"  // 3 thrower
    #expect(!draft.isValid)  // points still missing
    draft.points = 25  // 4 the 25 chip
    #expect(draft.input(rules: .standard) != nil)  // 5 Save is now possible
  }

  @Test func selfPickNeedsNoThrower() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.selfPick)
    draft.points = 30
    let input = draft.input(rules: .standard)
    #expect(input?.discarderID == nil)
    #expect(input?.basePoints == 30)
  }

  @Test func zeroPointsIsInvalid() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.selfPick)
    #expect(!draft.isValid)
  }

  @Test func changingTheWinnerDropsAThrowerWhoIsNowTheWinner() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.discard)
    draft.discarderID = "b"
    draft.points = 25
    draft.selectWinner("b")
    #expect(draft.discarderID == nil)
    #expect(!draft.isValid)
  }

  @Test func switchingToSelfPickClearsTheThrower() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.discard)
    draft.discarderID = "b"
    draft.points = 25
    draft.selectHow(.selfPick)
    #expect(draft.discarderID == nil)
    #expect(draft.input(rules: .standard)?.discarderID == nil)
  }

  @Test func choosingALineFillsPointsAndLabel() {
    var draft = RecordHandDraft()
    let even = line("Even Climb")
    draft.apply(line: even, cardID: PracticeCard.card.id)
    #expect(draft.points == even.points)
    #expect(draft.lineLabel == "Even Climb")
    #expect(draft.lineID == even.id)
    #expect(draft.cardID == "practice-v1")
    #expect(!draft.lineHasNoJokerGroups)
    #expect(!draft.isCustomValue)
  }

  @Test func editingPointsAfterChoosingALineKeepsTheLabelAndMarksCustom() {
    var draft = RecordHandDraft()
    draft.apply(line: line("Even Climb"), cardID: "practice-v1")
    draft.points = 40
    #expect(draft.isCustomValue)
    #expect(draft.lineLabel == "Even Climb")
    draft.points = draft.linePoints ?? 0
    #expect(!draft.isCustomValue)
  }

  @Test func clearingTheLineForgetsIt() {
    var draft = RecordHandDraft()
    draft.apply(line: line("Even Climb"), cardID: "practice-v1")
    draft.clearLine()
    #expect(!draft.hasLine)
    #expect(draft.lineID == nil)
    #expect(draft.cardID == nil)
    #expect(!draft.isCustomValue)
  }

  @Test func singlesAndPairsLinesDisableJokerlessUnlessTheRuleIsOn() {
    var draft = RecordHandDraft()
    draft.apply(line: line("Winds And Likes"), cardID: "practice-v1")
    #expect(draft.lineHasNoJokerGroups)
    #expect(!draft.jokerlessEnabled(rules: .standard))
    var bonus = RuleSet.standard
    bonus.jokerlessBonusForNoJokerLines = true
    #expect(draft.jokerlessEnabled(rules: bonus))
  }

  @Test func jokerlessIsDroppedFromTheInputWhenDisabled() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.selfPick)
    draft.apply(line: line("Winds And Likes"), cardID: "practice-v1")
    draft.jokerless = true
    #expect(draft.input(rules: .standard)?.jokerless == false)
    var bonus = RuleSet.standard
    bonus.jokerlessBonusForNoJokerLines = true
    #expect(draft.input(rules: bonus)?.jokerless == true)
  }

  @Test func jokerlessCarriesThroughForOrdinaryLines() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.selfPick)
    draft.apply(line: line("Even Climb"), cardID: "practice-v1")
    draft.jokerless = true
    #expect(draft.input(rules: .standard)?.jokerless == true)
  }

  @Test func noteIsTrimmedAndEmptyBecomesNil() {
    var draft = RecordHandDraft()
    draft.selectWinner("a")
    draft.selectHow(.selfPick)
    draft.points = 25
    draft.note = "   "
    #expect(draft.input(rules: .standard)?.note == nil)
    draft.note = "  last tile  "
    #expect(draft.input(rules: .standard)?.note == "last tile")
  }

  @Test func editingARecordedHandRestoresTheForm() {
    let even = line("Even Climb")
    let saved = MahjongInput(
      winnerID: "a", discarderID: "b", cardID: "practice-v1", lineID: even.id, lineLabel: "Even Climb",
      basePoints: 35, jokerless: true, note: "Fast")
    let draft = RecordHandDraft(editing: saved, card: PracticeCard.card)
    #expect(draft.winnerID == "a")
    #expect(draft.how == .discard)
    #expect(draft.discarderID == "b")
    #expect(draft.points == 35)
    #expect(draft.linePoints == even.points)
    #expect(draft.isCustomValue)
    #expect(draft.jokerless)
    #expect(draft.note == "Fast")
    #expect(draft.input(rules: .standard) == saved)
  }

  @Test func editingASelfPickWithoutALine() {
    let saved = MahjongInput(winnerID: "a", basePoints: 25)
    let draft = RecordHandDraft(editing: saved, card: nil)
    #expect(draft.how == .selfPick)
    #expect(!draft.hasLine)
    #expect(draft.input(rules: .standard) == saved)
  }

  @Test func aLineThatNoLongerExistsIsNotCustom() {
    let saved = MahjongInput(
      winnerID: "a", cardID: "gone", lineID: "x", lineLabel: "Old Hand", basePoints: 50)
    let draft = RecordHandDraft(editing: saved, card: nil)
    #expect(draft.hasLine)
    #expect(!draft.isCustomValue)
  }

  @Test func quickPointsAreTheSpecChips() {
    #expect(RecordHandDraft.quickPoints == [25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75])
  }
}
