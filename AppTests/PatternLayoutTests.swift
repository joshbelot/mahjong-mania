import MahjongCore
import Testing

@testable import MahjongMania

private struct ParseFailure: Error {
  let text: String
}

private func variant(_ text: String) throws -> PatternVariant {
  switch Notation.parseLine(text) {
  case .success(let line): return line.variants[0]
  case .failure: throw ParseFailure(text: text)
  }
}

private func bodies(_ layout: PatternLayout) -> [[String]] {
  layout.items.compactMap { item in
    if case .body(let parts) = item { return parts.map(\.glyphs) }
    return nil
  }
}

struct PatternLayoutTests {
  @Test func yearBodySplitsIntoOneClusterOfFourSingles() throws {
    let layout = PatternLayout(variant: try variant("FF 2026/x 2222/y 6666/y ; 25 ; X"))
    #expect(bodies(layout) == [["FF"], ["2", "0", "2", "6"], ["2222"], ["6666"]])
  }

  @Test func windsStayTogether() throws {
    let layout = PatternLayout(variant: try variant("NEWS FF 2222/x 2222/y ; 25 ; X"))
    #expect(bodies(layout) == [["N", "E", "W", "S"], ["FF"], ["2222"], ["2222"]])
  }

  @Test func mixedRunsInOneBodyShareACluster() throws {
    let layout = PatternLayout(variant: try variant("112233/x 445566/y FF ; 50 ; C"))
    #expect(bodies(layout) == [["11", "22", "33"], ["44", "55", "66"], ["FF"]])
  }

  @Test func operatorsSeparateBodies() throws {
    let layout = PatternLayout(variant: try variant("FF 3333/x + 4444/y = 7777/z ; 25 ; X"))
    let kinds = layout.items.map { item -> String in
      switch item {
      case .body(let parts): return parts.map(\.glyphs).joined()
      case .op(let text): return "op:" + text
      }
    }
    #expect(kinds == ["FF", "3333", "op:+", "4444", "op:=", "7777"])
  }

  @Test func groupIndexesFollowVariantGroups() throws {
    let pattern = try variant("FF 2026/x 2222/y 6666/y ; 25 ; X")
    let layout = PatternLayout(variant: pattern)
    #expect(layout.parts.map(\.groupIndex) == Array(0..<pattern.groups.count))
  }

  @Test func variablesAreColouredByVariable() throws {
    let layout = PatternLayout(variant: try variant("FF 2222/x 4444/y 6666/z ; 25 ; X"))
    #expect(
      layout.parts.map(\.ink) == [.flower, .variable(.x), .variable(.y), .variable(.z)])
  }

  @Test func fixedSuitsAreColouredBySuit() throws {
    let layout = PatternLayout(variant: try variant("FF 2222/c 3333/b 5555/d ; 25 ; X"))
    #expect(layout.parts.map(\.ink) == [.flower, .suit(.cracks), .suit(.bams), .suit(.dots)])
  }

  @Test func honorsUseTheHonorInk() throws {
    let layout = PatternLayout(variant: try variant("NNNN EEE WWW SSSS ; 25 ; X"))
    #expect(layout.parts.allSatisfy { $0.ink == .honor })
    #expect(layout.parts.map(\.glyphs) == ["NNNN", "EEE", "WWW", "SSSS"])
  }

  @Test func matchingDragonsTakeTheirSuitVariable() throws {
    let layout = PatternLayout(variant: try variant("NNN SSS DDDD/x DDDD/y ; 25 ; X"))
    #expect(layout.parts[2].glyphs == "DDDD")
    #expect(layout.parts[2].ink == .variable(.x))
    #expect(layout.parts[3].ink == .variable(.y))
  }

  @Test func suitLettersAreOffByDefault() throws {
    let layout = PatternLayout(variant: try variant("FF 2026/x 2222/y 6666/y ; 25 ; X"))
    #expect(layout.parts.allSatisfy { $0.suitLetter == nil })
  }

  @Test func suitLettersGoOnTheLastPartOfEachVariableInABody() throws {
    let layout = PatternLayout(
      variant: try variant("FF 2026/x 2222/y 6666/y ; 25 ; X"), showSuitLetters: true)
    // Parts: F, 2, 0, 2, 6, 2222, 6666
    #expect(layout.parts.map(\.suitLetter) == [nil, nil, nil, nil, "A", "B", "B"])
  }

  @Test func suitLettersWithRunsInOneBody() throws {
    let layout = PatternLayout(
      variant: try variant("112233/x 445566/y FF ; 50 ; C"), showSuitLetters: true)
    #expect(layout.parts.map(\.suitLetter) == [nil, nil, "A", nil, nil, "B", nil])
  }

  @Test func fixedSuitsHaveNoLetter() throws {
    let layout = PatternLayout(
      variant: try variant("FF 2222/c 3333/b 5555/d ; 25 ; X"), showSuitLetters: true)
    #expect(layout.parts.allSatisfy { $0.suitLetter == nil })
  }

  @Test func exampleTilesBindXYZToCracksBamsDots() {
    #expect(PatternLayout.exampleTile(for: .number(5, .variable(.x))) == .number(5, .cracks))
    #expect(PatternLayout.exampleTile(for: .number(5, .variable(.y))) == .number(5, .bams))
    #expect(PatternLayout.exampleTile(for: .matchingDragon(.variable(.z))) == .dragon(.white))
    #expect(PatternLayout.exampleTile(for: .number(2, .fixed(.dots))) == .number(2, .dots))
    #expect(PatternLayout.exampleTile(for: .fixed(.flower)) == .flower)
  }
}

struct PatternSlotTests {
  private let five = Tile.number(5, .dots)

  @Test func heldTilesAreNaturalAndMissingOnesAreMissing() {
    let groups = [
      TargetGroup(tile: five, count: 3, jokerOK: true, groupIndex: 0),
      TargetGroup(tile: .flower, count: 2, jokerOK: false, groupIndex: 1),
    ]
    let slots = PatternLayout.slots(
      groups: groups, missing: [MissingTile(tile: .flower, count: 1, jokerOK: false)],
      naturalsHeld: [five: 3, .flower: 1], jokersUsed: 0)
    #expect(slots[0].map(\.kind) == [.natural, .natural, .natural])
    #expect(slots[1].map(\.kind) == [.natural, .missing])
  }

  @Test func jokersFillWhatNaturalsDoNotCover() {
    let groups = [TargetGroup(tile: five, count: 3, jokerOK: true, groupIndex: 0)]
    let slots = PatternLayout.slots(
      groups: groups, missing: [], naturalsHeld: [five: 2], jokersUsed: 1)
    #expect(slots[0].map(\.kind) == [.natural, .natural, .joker])
  }

  @Test func shortfallInAJokerGroupIsMissing() {
    let groups = [TargetGroup(tile: five, count: 3, jokerOK: true, groupIndex: 0)]
    let slots = PatternLayout.slots(
      groups: groups, missing: [MissingTile(tile: five, count: 1, jokerOK: true)],
      naturalsHeld: [five: 2], jokersUsed: 0)
    #expect(slots[0].map(\.kind) == [.natural, .natural, .missing])
  }

  @Test func plainGroupsNeverGetJokers() {
    let groups = [TargetGroup(tile: .flower, count: 2, jokerOK: false, groupIndex: 0)]
    let slots = PatternLayout.slots(
      groups: groups, missing: [MissingTile(tile: .flower, count: 2, jokerOK: false)],
      naturalsHeld: [:], jokersUsed: 2)
    #expect(slots[0].map(\.kind) == [.missing, .missing])
  }

  @Test func resultIsAlignedWithGroups() {
    let groups = [
      TargetGroup(tile: five, count: 3, jokerOK: true, groupIndex: 0),
      TargetGroup(tile: .flower, count: 2, jokerOK: false, groupIndex: 1),
    ]
    let slots = PatternLayout.slots(groups: groups, missing: [], naturalsHeld: [:], jokersUsed: 0)
    #expect(slots.map(\.count) == [3, 2])
    #expect(slots[0].allSatisfy { $0.tile == five })
  }
}
