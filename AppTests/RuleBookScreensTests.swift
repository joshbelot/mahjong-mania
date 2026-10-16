import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

struct RuleTextsTests {
  @Test func everyBuiltInHasPlainText() {
    var titles = Set<String>()
    for definition in RuleCatalog.builtIns {
      let rule = definition.defaultRule
      let text = RuleTexts.text(for: rule)
      #expect(!text.title.isEmpty && text.title != rule.id, "\(rule.id) needs a title")
      #expect(text.meaning.count > 30, "\(rule.id) needs a meaning")
      #expect(titles.insert(text.title).inserted, "\(rule.id) title is not unique")
      for banned in ["NMJL", "National Mah Jongg"] {
        #expect(!text.title.contains(banned) && !text.meaning.contains(banned))
      }
    }
  }

  @Test func titlesFollowTheChoice() {
    var rules = RuleSet.standard
    #expect(RuleTexts.text(for: rules.rule(RuleID.jokerless)!).title == "A jokerless hand pays double")
    rules.setMultiple(RuleID.jokerless, 3)
    #expect(RuleTexts.text(for: rules.rule(RuleID.jokerless)!).title == "A jokerless hand pays triple")
    rules.setMultiple(RuleID.others, 0)
    #expect(RuleTexts.text(for: rules.rule(RuleID.others)!).title == "Everyone else pays nothing")
    #expect(RuleTexts.choiceText(for: rules.rule(RuleID.others)!) == "Others pay nothing")
    #expect(RuleTexts.choiceText(for: rules.rule(RuleID.discarder)!) == "Thrower pays double")
    #expect(RuleTexts.choiceText(for: rules.rule(RuleID.wall)!) == nil)
  }

  @Test func choiceNames() {
    #expect([0, 1, 2, 3, 4].map(RuleTexts.multipleName) == ["Nothing", "Single", "Double", "Triple", "Quadruple"])
  }
}

struct RuleExamplesTests {
  @Test func standardDiscardExampleMatchesTheSpec() {
    #expect(
      RuleExamples.text(.discard, rules: .standard)
        == "Bea wins a 25-point hand from Cy's discard: Cy pays 50, Dee and Al pay 25 each. Bea collects 100.")
  }

  @Test func selfPickAndJokerlessExamples() {
    #expect(
      RuleExamples.text(.selfPicked, rules: .standard)
        == "Bea wins a 25-point hand by drawing the winning tile: Cy, Dee and Al pay 50 each. Bea collects 150.")
    var rules = RuleSet.standard
    rules.setMultiple(RuleID.jokerless, 3)
    #expect(
      RuleExamples.text(.jokerlessDiscard, rules: rules)
        == "Bea wins a 25-point hand from Cy's discard (with no jokers): Cy pays 150, Dee and Al pay 75 each. Bea collects 300.")
  }

  @Test func theExampleChangesWithTheRuleBook() {
    var rules = RuleSet.standard
    let before = RuleExamples.text(.jokerlessDiscard, rules: rules)
    rules.setMultiple(RuleID.jokerless, 3)
    #expect(RuleExamples.text(.jokerlessDiscard, rules: rules) != before)
    rules.setEnabled(RuleID.discarderPaysAll, true)
    #expect(
      RuleExamples.text(.discard, rules: rules)
        == "Bea wins a 25-point hand from Cy's discard: Cy pays 100, Dee and Al pay nothing. Bea collects 100.")
  }

  @Test func onlyScoringRulesGetALiveExample() {
    let rules = RuleSet.standard
    #expect(RuleExamples.example(forRule: rules.rule(RuleID.discarder)!, in: rules) != nil)
    #expect(RuleExamples.example(forRule: rules.rule(RuleID.courtesy)!, in: rules) == nil)
  }

  @Test func customRuleExampleUsesItsOwnScenario() {
    var rules = RuleSet.standard
    let effect = CustomEffect(condition: .selfPick, payers: .everyone, action: .addPoints(10))
    let rule = HouseRule(id: "custom.t", custom: CustomRule(title: "t", text: "", effect: effect))
    rules.addCustom(rule)
    #expect(
      RuleExamples.example(forRule: rule, in: rules)
        == "Bea wins a 25-point hand by drawing the winning tile: Cy, Dee and Al pay 60 each. Bea collects 180.")
  }

  @Test func sentencesReadAsAThought() {
    let effect = CustomEffect(condition: .selfPick, payers: .everyone, action: .multiply(2))
    #expect(RuleSentences.sentence(for: effect) == "On a self-pick, everyone pays double.")
    #expect(RuleSentences.autoTitle(for: effect) == "On a self-pick: everyone pays double")
    let east = CustomEffect(condition: .eastWins, payers: .everyoneButDiscarder, action: .addPoints(5))
    #expect(RuleSentences.sentence(for: east) == "When East wins, everyone except the thrower pays 5 extra points.")
    let line = CustomEffect(condition: .line(id: "L_1", label: "Evens #1"), payers: .discarderOnly, action: .multiply(3))
    #expect(RuleSentences.sentence(for: line) == "On Evens #1, the thrower pays triple.")
    #expect(RuleSentences.how(.multiply(2), payers: .everyone) == "Everyone pays double")
  }
}

struct RuleSummaryTests {
  @Test func standardIsRecognisedAndWordsAreShort() {
    #expect(RulesSummary.matchesStandard(.standard))
    #expect(
      RulesSummary.text(.standard) == "Thrower pays double \u{00B7} Self-pick pays double \u{00B7} Jokerless pays double")
    #expect(RulesSummary.title(.standard) == "Standard rules")
  }

  @Test func changesAreMentioned() {
    var rules = RuleSet.standard
    rules.setMultiple(RuleID.jokerless, 3)
    #expect(!RulesSummary.matchesStandard(rules))
    #expect(RulesSummary.title(rules) == "Custom rules")
    rules.setEnabled(RuleID.courtesy, false)
    rules.addCustom(
      HouseRule(
        id: "custom.a",
        custom: CustomRule(
          title: "A", text: "",
          effect: CustomEffect(condition: .always, payers: .everyone, action: .multiply(2)))))
    let text = RulesSummary.text(rules)
    #expect(text.contains("Jokerless pays triple"))
    #expect(text.contains("1 house rule"))
    #expect(text.contains("1 switched off"))
  }
}

struct HouseRulesLearnTests {
  @Test func topicListsEveryRuleAndOurRules() {
    var rules = RuleSet.standard
    rules.setEnabled(RuleID.courtesy, false)
    rules.addCustom(
      HouseRule(id: "custom.n", custom: CustomRule(title: "No phones", text: "Phones stay in the bag.")))
    let topic = LearnHouseRules.topic(for: rules)
    #expect(topic.title == "House rules explained")
    #expect(topic.sections.map(\.id).last == "ours")
    #expect(topic.sections.count == RuleCategory.allCases.count + 1)
    let strings = topic.sections.flatMap { section in
      section.blocks.flatMap { block -> [String] in
        switch block {
        case .bullets(let items): return items
        case .paragraph(let text): return [text]
        default: return []
        }
      }
    }
    #expect(strings.contains { $0.contains("Courtesy pass across: 0 to 3 tiles (off)") })
    #expect(strings.contains { $0.contains("Concealed hands (C) (always on)") })
    #expect(strings.contains { $0.contains("No phones (note). Phones stay in the bag.") })
    for section in topic.sections { #expect(!section.blocks.isEmpty) }
  }

  @Test func quickReferencePointsToIt() {
    for id in ["charleston", "jokers", "paying"] {
      let section = LearnRules.topic.sections.first { $0.id == id }
      #expect(
        section?.blocks.contains {
          if case .note(let text) = $0 { return text.contains("House rules explained") }
          return false
        } == true)
    }
  }
}

struct HouseRuleExplanationTests {
  private let seats = ["Bea", "Cy", "Alex", "Dee"]
  private let names = ["Bea": "Bea", "Cy": "Cy", "Alex": "Alex", "Dee": "Dee"]

  private func explain(_ input: MahjongInput, rules: RuleSet, coach: Bool) -> String {
    let payments = Scoring.payments(for: .mahjong(input), seats: seats, dealerID: "Dee", rules: rules)
    return PaymentExplanation.text(
      input: input, seats: seats, payments: payments, rules: rules, names: names, coach: coach,
      dealerID: "Dee")
  }

  @Test func customRulesAreNamedWhenTheyApply() {
    var rules = RuleSet.standard
    rules.addCustom(
      HouseRule(
        id: "custom.s",
        custom: CustomRule(
          title: "Self-pick bonus", text: "",
          effect: CustomEffect(condition: .selfPick, payers: .everyone, action: .addPoints(10)))))
    let selfPick = MahjongInput(winnerID: "Bea", basePoints: 25)
    #expect(explain(selfPick, rules: rules, coach: true).hasSuffix("House rule: Self-pick bonus."))
    #expect(explain(selfPick, rules: rules, coach: false).hasSuffix("\u{00B7} Self-pick bonus"))
    let discard = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 25)
    #expect(!explain(discard, rules: rules, coach: true).contains("House rule"))
  }

  @Test func theThrowerPaysForEveryoneIsExplained() {
    var rules = RuleSet.standard
    rules.setEnabled(RuleID.discarderPaysAll, true)
    let input = MahjongInput(winnerID: "Bea", discarderID: "Cy", basePoints: 25)
    #expect(explain(input, rules: rules, coach: false) == "Cy pays 100 for everyone (house rule)")
    #expect(explain(input, rules: rules, coach: true).contains("the thrower pays for everyone"))
  }
}
