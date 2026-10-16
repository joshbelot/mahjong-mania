import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)

@MainActor
struct BlankStoreTests {
  @Test func theBlankCapIsTheRulesCount() {
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    #expect(!store.canAdd(.blank), "the rule is off")
    #expect(!store.add(.blank))
    store.blankLimit = 2
    #expect(store.add(.blank))
    #expect(store.add(.blank))
    #expect(!store.add(.blank))
    #expect(store.rack == [.blank, .blank])
    #expect(store.canAdd(.joker), "other tiles keep their own copies")
    store.blankLimit = 6
    #expect(store.add(.blank))
  }

  @Test func blanksSurviveARelaunch() {
    let directory = makeTempDirectory()
    let store = HelperStore(directory: directory, persistDelay: fast)
    store.blankLimit = 4
    store.add(.blank)
    store.add(.number(5, .dots))
    store.flush()
    let reloaded = HelperStore(directory: directory, persistDelay: fast)
    #expect(reloaded.rack == [.blank, .number(5, .dots)])
  }

  @Test func resultsAreRecomputedWhenThePolicyChanges() {
    let analyzer = Analyzer(card: PracticeCard.card)
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    store.setRack(LaunchOptions.tiles(fromCodes: "2B,2B,2B,4B,4B,4B,4B,6B,6B,8B,8B,8B,BL"))
    _ = store.results(using: analyzer)
    _ = store.results(using: analyzer)
    #expect(store.analysisCount == 1)
    store.blankPolicy = BlankPolicy(swapForJoker: true)
    _ = store.results(using: analyzer)
    #expect(store.analysisCount == 2)
  }

  @Test func theAdvisorMemoisesSwapAdvice() {
    let analyzer = Analyzer(card: PracticeCard.card)
    let advisor = HelperAdvisor()
    let view = PlayerView(rack: LaunchOptions.tiles(fromCodes: "2B,2B,2B,4B,4B,4B,4B,6B,6B,8B,8B,8B,BL"))
    let seen: TileCounts = [.number(6, .bams): 1]
    let first = advisor.blankSwaps(analyzer, view: view, seen: seen, policy: BlankPolicy())
    let again = advisor.blankSwaps(analyzer, view: view, seen: seen, policy: BlankPolicy())
    #expect(first == again)
    #expect(advisor.computations == 1)
    #expect(first.first?.tile == .number(6, .bams))
  }

  @Test func theRuleOptionsReachTheStore() {
    var rules = RuleSet.standard
    #expect(rules.blanks == nil)
    rules.update(RuleID.blanks) {
      $0.isEnabled = true
      $0.blanks = BlankOptions(count: 4, swapForJoker: true)
    }
    #expect(rules.blanks?.count == 4)
    #expect(rules.blanks?.swapForJoker == true)
  }

  @Test func glossaryAndLearnMentionBlanks() {
    #expect(Glossary.entries.contains { $0.term == "Blank" })
    var rules = RuleSet.standard
    let topic = LearnHouseRules.topic(for: rules)
    #expect(topic.sections.contains { $0.id == "cat-blanks" && $0.heading == "Blanks" })
    rules.setEnabled(RuleID.blanks, true)
    #expect(RuleTexts.choiceText(for: rules.rule(RuleID.blanks)!) == "6 blanks")
  }
}
