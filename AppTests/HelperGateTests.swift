import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

struct HelperGateTests {
  @Test func offHidesTheTabAndEverythingElse() {
    let gate = HelperGate(.off)
    #expect(!gate.showsHelperTab)
    #expect(!gate.showsClosestHands(revealed: true))
    #expect(gate.visibleHandCount(total: 20, showAll: true) == 0)
    #expect(!gate.showsSuggestions(revealed: true))
    #expect(!gate.canExpandHands)
    #expect(!gate.offersCallCheck)
    #expect(!gate.showsDanger)
    #expect(!gate.showsTips)
  }

  @Test func peekNeedsATapToShowHands() {
    let gate = HelperGate(.peek)
    #expect(gate.showsHelperTab)
    #expect(!gate.showsClosestHands(revealed: false))
    #expect(gate.showsClosestHands(revealed: true))
    #expect(gate.visibleHandCount(total: 20, showAll: false) == 3)
    #expect(gate.visibleHandCount(total: 20, showAll: true) == 3)
    #expect(gate.visibleHandCount(total: 2, showAll: false) == 2)
    #expect(!gate.offersShowAll(total: 20))
    #expect(!gate.showsMissingInline)
    #expect(gate.canExpandHands)
  }

  @Test func peekNeedsATapToShowSuggestions() {
    let gate = HelperGate(.peek)
    #expect(!gate.showsSuggestions(revealed: false))
    #expect(gate.showsSuggestions(revealed: true))
  }

  @Test func peekOffersCallCheckAndDangerButNoExplanations() {
    let gate = HelperGate(.peek)
    #expect(gate.offersCallCheck)
    #expect(!gate.explainsCalls)
    #expect(gate.showsDanger)
    #expect(!gate.showsDangerReasons)
    #expect(!gate.showsTips)
  }

  @Test func coachShowsEverythingWithoutATap() {
    let gate = HelperGate(.coach)
    #expect(gate.showsHelperTab)
    #expect(gate.showsClosestHands(revealed: false))
    #expect(gate.showsSuggestions(revealed: false))
    #expect(gate.showsMissingInline)
    #expect(gate.explainsCalls)
    #expect(gate.showsDangerReasons)
    #expect(gate.showsTips)
  }

  @Test func coachListsEightThenAll() {
    let gate = HelperGate(.coach)
    #expect(gate.visibleHandCount(total: 40, showAll: false) == 8)
    #expect(gate.visibleHandCount(total: 40, showAll: true) == 40)
    #expect(gate.visibleHandCount(total: 5, showAll: false) == 5)
    #expect(gate.offersShowAll(total: 40))
    #expect(!gate.offersShowAll(total: 8))
  }

  @Test func rackLimitsFollowTheMode() {
    #expect(HelperRules.rackLimit(mode: .charleston, exposedTiles: 0) == 14)
    #expect(HelperRules.rackLimit(mode: .playing, exposedTiles: 0) == 14)
    #expect(HelperRules.rackLimit(mode: .playing, exposedTiles: 3) == 11)
    #expect(HelperRules.rackLimit(mode: .playing, exposedTiles: 20) == 0)
    #expect(HelperRules.fullRackCount(mode: .charleston, exposedTiles: 0) == 13)
    #expect(HelperRules.fullRackCount(mode: .playing, exposedTiles: 3) == 11)
    #expect(HelperRules.fullRackCount(mode: .playing, exposedTiles: 20) == 1)
  }
}

struct HelperTextTests {
  @Test func focusSentenceNamesOneTwoOrThreeSections() {
    #expect(HelperText.focusSegments([]).isEmpty)
    let one = HelperText.focusSegments(["2468"])
    #expect(one.map(\.text).joined() == "Keep options open: you're strongest in 2468.")
    #expect(one.filter(\.bold).map(\.text) == ["2468"])
    let two = HelperText.focusSegments(["2468", "13579"])
    #expect(two.map(\.text).joined() == "Keep options open: you're strongest in 2468 and 13579.")
    #expect(two.filter(\.bold).map(\.text) == ["2468", "13579"])
    let three = HelperText.focusSegments(["A", "B", "C"])
    #expect(three.map(\.text).joined() == "Keep options open: you're strongest in A, B and C.")
  }

  @Test func groupNames() {
    #expect(HelperText.groupNoun(3) == "pung")
    #expect(HelperText.groupNoun(4) == "kong")
    #expect(HelperText.groupNoun(5) == "quint")
    #expect(HelperText.groupNoun(6) == "sextet")
  }

  @Test func verdictWording() {
    let line = PracticeCard.card.lines[0]
    #expect(HelperText.headline(for: .mahjong(line)) == "Call it \u{2014} that's Mahjong!")
    #expect(
      HelperText.headline(for: .expose(line, groupSize: 3, newDistance: 1))
        == "Expose a pung \u{2014} you'd be 1 away")
    #expect(
      HelperText.headline(for: .expose(line, groupSize: 4, newDistance: 2))
        == "Expose a kong \u{2014} you'd be 2 away")
    #expect(HelperText.letItGo == "Let it go \u{2014} it doesn't help your top hands.")
    let explanation = HelperText.explanation(
      for: .expose(line, groupSize: 3, newDistance: 1), tile: .number(6, .bams))
    #expect(explanation.contains("pung of 6 Bam"))
    #expect(explanation.contains(line.displayName))
  }

  @Test func awayWording() {
    #expect(HelperText.away(distance: 0) == "Mahjong!")
    #expect(HelperText.away(distance: 4) == "4 away")
  }

  @Test func exposureDescriptions() {
    let six = Tile.number(6, .dots)
    #expect(exposureDescription(Exposure(tiles: [six, six, six])) == "Pung of 6 Dot")
    #expect(exposureDescription(Exposure(tiles: [six, six, .joker, .joker])) == "Kong of 6 Dot, 2 jokers")
    #expect(exposureDescription(Exposure(tiles: [six, .joker, .joker])) == "Pung of 6 Dot, 2 jokers")
    #expect(exposureDescription(Exposure(tiles: [six, six, six, .joker])) == "Kong of 6 Dot, 1 joker")
  }
}

@MainActor
struct HelperLaunchOptionsTests {
  private let reset = "-UITestResetData"

  @Test func parsesATileList() {
    #expect(LaunchOptions.tiles(fromCodes: "1C, 2B,N,J,nonsense,0").map(\.code) == ["1C", "2B", "N", "J", "0"])
  }

  @Test func rackIsHonouredOnlyWithResetData() {
    let withReset = [reset, "-UITestHelperRack", "1C,1C,F"]
    #expect(LaunchOptions.helperRack(arguments: withReset)?.map(\.code) == ["1C", "1C", "F"])
    #expect(LaunchOptions.helperRack(arguments: ["-UITestHelperRack", "1C"]) == nil)
    #expect(LaunchOptions.helperRack(arguments: [reset]) == nil)
    #expect(LaunchOptions.helperRack(arguments: [reset, "-UITestHelperRack"]) == nil)
  }

  @Test func assistAndModeAreParsed() {
    #expect(LaunchOptions.assistLevel(arguments: [reset, "-UITestAssist", "coach"]) == .coach)
    #expect(LaunchOptions.assistLevel(arguments: [reset, "-UITestAssist", "off"]) == .off)
    #expect(LaunchOptions.assistLevel(arguments: ["-UITestAssist", "off"]) == nil)
    #expect(LaunchOptions.assistLevel(arguments: [reset, "-UITestAssist", "loud"]) == nil)
    #expect(LaunchOptions.helperMode(arguments: [reset, "-UITestHelperMode", "scout"]) == .scout)
    #expect(LaunchOptions.helperMode(arguments: ["-UITestHelperMode", "scout"]) == nil)
  }

  @Test func launchOptionsLoadTheStores() {
    let stores = AppStores.inMemory()
    stores.applyHelperLaunchOptions(arguments: [
      reset, "-UITestAssist", "coach", "-UITestHelperRack", "1C,2C,3C", "-UITestHelperMode", "playing",
    ])
    #expect(stores.settings.settings.assistLevel == .coach)
    #expect(stores.helper.rack.map(\.code) == ["1C", "2C", "3C"])
    #expect(stores.helper.mode == .playing)
  }

  @Test func launchOptionsDoNothingWithoutArguments() {
    let stores = AppStores.inMemory()
    stores.applyHelperLaunchOptions(arguments: [reset])
    #expect(stores.settings.settings.assistLevel == .peek)
    #expect(stores.helper.rack.isEmpty)
    #expect(stores.helper.mode == .charleston)
  }
}

struct HelperAdvisorTests {
  private let analyzer = Analyzer(card: PracticeCard.card)
  private let view = PlayerView(
    rack: ["1C", "2C", "3C", "5D", "5D", "6D", "6D", "6D", "N", "R", "0", "F", "J"].compactMap { Tile(code: $0) })

  @Test func repeatedQuestionsDoNotRunTheEngineAgain() {
    let advisor = HelperAdvisor()
    let first = advisor.passes(analyzer, view: view)
    let second = advisor.passes(analyzer, view: view)
    #expect(advisor.computations == 1)
    #expect(first.passes.map(\.tile) == second.passes.map(\.tile))
    // The order the tiles were entered in does not matter.
    _ = advisor.passes(analyzer, view: PlayerView(rack: view.rack.reversed()))
    #expect(advisor.computations == 1)
  }

  @Test func changedInputsRunTheEngineAgain() {
    let advisor = HelperAdvisor()
    _ = advisor.passes(analyzer, view: view)
    var changed = view
    changed.rack.removeLast()
    _ = advisor.passes(analyzer, view: changed)
    #expect(advisor.computations == 2)
    _ = advisor.scout(analyzer, opponents: [], seen: [:])
    _ = advisor.scout(analyzer, opponents: [], seen: [:])
    #expect(advisor.computations == 3)
    _ = advisor.scout(analyzer, opponents: [], seen: [.number(1, .cracks): 2])
    #expect(advisor.computations == 4)
  }

  @Test func passAdviceNeverIncludesAJoker() {
    let advice = HelperAdvisor().passes(analyzer, view: view)
    #expect(advice.passes.count == 3)
    #expect(!advice.passes.contains { $0.tile == .joker })
  }
}
