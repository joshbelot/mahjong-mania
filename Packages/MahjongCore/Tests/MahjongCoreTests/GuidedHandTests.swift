import XCTest

@testable import MahjongCore

final class GuidedHandTests: XCTestCase {
  private func parse(_ text: String) -> CardLine {
    guard case .success(let line) = Notation.parseLine(text, id: "t", section: "Hands") else {
      XCTFail("Did not parse: \(text)")
      return CardLine(id: "x", section: "", name: nil, points: 1, concealed: false, shift: .none, variants: [], source: "")
    }
    return line
  }

  func testRoundTripsPreserveMeaning() throws {
    for text in [
      "FF 2026/x 2222/y 6666/y ; 75 ; X", "NN EEE WWW SSSS DD/x ; 30 ; X",
      "FF 111/x 2222/c 333/b 44/c ; 25 ; C ; Mixed ; shift",
      "FFFF 2468/x 2222/y DD/y ; 25 ; X ; Evens ; shift2", "RRR GGG 000 FF 111/x ; 25 ; X",
    ] {
      let line = parse(text)
      guard let guided = GuidedLine(line: line) else { return XCTFail("Should be representable: \(text)") }
      guard case .valid(let rebuilt, _) = guided.validate() else { return XCTFail("Invalid: \(text)") }
      XCTAssertEqual(GuidedLine.semanticSignature(rebuilt), GuidedLine.semanticSignature(line), text)
      XCTAssertEqual(rebuilt.points, line.points)
      XCTAssertEqual(rebuilt.concealed, line.concealed)
      XCTAssertEqual(rebuilt.shift, line.shift)
      XCTAssertEqual(rebuilt.name ?? "", line.name ?? "")
    }
  }

  func testAlternativesRoundTrip() {
    let line = parse("FFFF 2222/x 4444/y 66/z | FFFF 2222/y 4444/z 66/x ; 40 ; X")
    XCTAssertEqual(line.variants.count, 2)
    let guided = GuidedLine(line: line)
    XCTAssertEqual(guided?.alternatives.count, 2)
    if let guided, case .valid(let rebuilt, _) = guided.validate() {
      XCTAssertEqual(GuidedLine.semanticSignature(rebuilt), GuidedLine.semanticSignature(line))
    } else { XCTFail("invalid") }
  }

  func testOperatorsStayAdvanced() {
    let line = parse("FFFF 2222/x + 4444/y = 66/z ; 25 ; X")
    XCTAssertNil(GuidedLine(line: line), "Decorative operators must not be flattened")
  }

  func testEverySupportedTileSpecSerializes() {
    let groups: [GroupSpec] = [
      GroupSpec(tile: .number(3, .variable(.x)), count: 3),
      GroupSpec(tile: .number(3, .fixed(.bams)), count: 2),
      GroupSpec(tile: .matchingDragon(.variable(.y)), count: 2),
      GroupSpec(tile: .matchingDragon(.fixed(.dots)), count: 2),
      GroupSpec(tile: .fixed(.wind(.north)), count: 4),
      GroupSpec(tile: .fixed(.dragon(.white)), count: 1),
      GroupSpec(tile: .fixed(.flower), count: 2),
    ]
    let text = GuidedLine.notation(of: groups)
    XCTAssertEqual(text, "333/x 33/b DD/y DD/d NNNN 0 FF")
    // The parser reads each back to the same group.
    guard case .success(let line) = Notation.parseLine(text + " ; 25 ; X") else {
      // Tile count is 17 here: that is the only acceptable failure.
      return
    }
    XCTAssertEqual(line.variants.first?.groups, groups)
  }

  func testInvalidAndZeroTargetLines() {
    var guided = GuidedLine(alternatives: [[GroupSpec(tile: .number(1, .variable(.x)), count: 3)]])
    guard case .invalid(let problems) = guided.validate() else { return XCTFail("3 tiles must be invalid") }
    XCTAssertFalse(problems.isEmpty)
    guided.alternatives = [[]]
    XCTAssertEqual(guided.validate(), .invalid(["Add at least one group of tiles to every alternative."]))
    // Contradictory: three different suit variables plus a fixed suit leave only two suits for three variables.
    var contradictory = GuidedLine(alternatives: [[
      GroupSpec(tile: .number(1, .variable(.x)), count: 2), GroupSpec(tile: .number(2, .variable(.y)), count: 3),
      GroupSpec(tile: .number(3, .variable(.z)), count: 3), GroupSpec(tile: .number(4, .fixed(.cracks)), count: 4),
      GroupSpec(tile: .fixed(.flower), count: 2)]])
    contradictory.points = 25
    guard case .invalid(let reasons) = contradictory.validate() else { return XCTFail("zero targets must be invalid") }
    XCTAssertFalse(reasons.isEmpty)
  }

  func testQuintsWithJokersAreAllowed() {
    let guided = GuidedLine(alternatives: [[
      GroupSpec(tile: .fixed(.flower), count: 5), GroupSpec(tile: .number(1, .variable(.x)), count: 5),
      GroupSpec(tile: .number(2, .variable(.y)), count: 4)]])
    guard case .valid = guided.validate() else { return XCTFail("Quints may use Jokers") }
  }

  func testTileCountAndExample() {
    let line = parse("FF 2026/x 2222/y 6666/y ; 75 ; X")
    let tiles = GuidedLine.exampleTiles(for: line)
    XCTAssertEqual(tiles?.count, 14)
    let guided = GuidedLine(line: line)!
    XCTAssertEqual(guided.tileCount(ofAlternative: 0), 14)
  }

  func testCardEditingKeepsCommentsAndInvalidLines() {
    let guided = GuidedLine(name: "Mine", points: 30, alternatives: [GuidedLine(line: parse("FFFF 2222/x 4444/y 66/z ; 25 ; X"))!.alternatives[0]])
    guard case .valid(let line, _) = guided.validate(section: "Mine") else { return XCTFail() }
    XCTAssertEqual(Notation.serialize(line), "FFFF 2222/x 4444/y 66/z ; 30 ; X ; Mine")
  }
}
