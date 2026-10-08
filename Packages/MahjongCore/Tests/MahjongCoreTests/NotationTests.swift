import Foundation
import Testing

@testable import MahjongCore

private func parse(_ text: String) -> CardLine? {
  if case .success(let line) = Notation.parseLine(text) { return line }
  return nil
}

private func errors(_ text: String) -> [ParseError] {
  if case .failure(let list) = Notation.parseLine(text) { return list.errors }
  return []
}

struct BodySplittingTests {
  @Test func kongOfTwos() throws {
    let line = try #require(parse("2222/x 000 22/y 66/y 666/z ; 25 ; X"))
    #expect(line.variants[0].groups.first == GroupSpec(tile: .number(2, .variable(.x)), count: 4))
  }

  @Test func yearBodySplitsIntoSingles() throws {
    let line = try #require(parse("FF 2026/x 2222/y 6666/y ; 25 ; X"))
    let groups = line.variants[0].groups
    #expect(groups.count == 7)
    #expect(groups[0] == GroupSpec(tile: .fixed(.flower), count: 2))
    #expect(groups[1] == GroupSpec(tile: .number(2, .variable(.x)), count: 1))
    #expect(groups[2] == GroupSpec(tile: .fixed(.dragon(.white)), count: 1))
    #expect(groups[3] == GroupSpec(tile: .number(2, .variable(.x)), count: 1))
    #expect(groups[4] == GroupSpec(tile: .number(6, .variable(.x)), count: 1))
    #expect(groups[5] == GroupSpec(tile: .number(2, .variable(.y)), count: 4))
    #expect(groups[6] == GroupSpec(tile: .number(6, .variable(.y)), count: 4))
  }

  @Test func mixedRunsInOneBody() throws {
    let line = try #require(parse("11222/x FFFF 999/y FF ; 25 ; X"))
    let groups = line.variants[0].groups
    #expect(groups[0] == GroupSpec(tile: .number(1, .variable(.x)), count: 2))
    #expect(groups[1] == GroupSpec(tile: .number(2, .variable(.x)), count: 3))
  }

  @Test func windsAreSingles() throws {
    let line = try #require(parse("NEWS NNNN EEEE 11/x ; 25 ; X"))
    let groups = line.variants[0].groups
    #expect(groups.prefix(4).map(\.count) == [1, 1, 1, 1])
    #expect(groups[0].tile == .fixed(.wind(.north)))
    #expect(groups[3].tile == .fixed(.wind(.south)))
  }

  @Test func flowersCanFormAKong() throws {
    let line = try #require(parse("FFFF 2222/x 3333/x 55/x ; 25 ; X"))
    #expect(line.variants[0].groups[0] == GroupSpec(tile: .fixed(.flower), count: 4))
  }

  @Test func fixedSuitsAndMatchingDragons() throws {
    let line = try #require(parse("DDDD/c 2222/b 3333/d FF ; 25 ; X"))
    let groups = line.variants[0].groups
    #expect(groups[0].tile == .matchingDragon(.fixed(.cracks)))
    #expect(groups[1].tile == .number(2, .fixed(.bams)))
    #expect(groups[2].tile == .number(3, .fixed(.dots)))
  }

  @Test func suitIsIgnoredForHonours() throws {
    let line = try #require(parse("NNNN/x FF/y 2222/x 3333/x ; 25 ; X"))
    #expect(line.variants[0].groups[0].tile == .fixed(.wind(.north)))
  }

  @Test func operatorsAreKeptAsTokensButNotGroups() throws {
    let line = try #require(parse("FF 3333/x + 4444/y = 7777/z ; 25 ; X"))
    let tokens = line.variants[0].tokens
    let ops = tokens.compactMap { token -> String? in
      if case .op(let text, _) = token { return text }
      return nil
    }
    #expect(ops == ["+", "="])
    #expect(line.variants[0].groups.count == 4)
    #expect(line.variants[0].source == "FF 3333/x + 4444/y = 7777/z")
  }

  @Test func decorativeMinusAndTimes() throws {
    let line = try #require(parse("FF 7777/x - 3333/y x 4444/z ; 25 ; X"))
    let ops = line.variants[0].tokens.compactMap { token -> String? in
      if case .op(let text, _) = token { return text }
      return nil
    }
    #expect(ops == ["-", "x"])
  }

  @Test func whitespaceIsNormalised() throws {
    let line = try #require(parse("  FF   2222/x  4444/y   66/z  ;25;   X  ;  Spacey  "))
    #expect(line.variants[0].source == "FF 2222/x 4444/y 66/z")
    #expect(line.name == "Spacey")
    #expect(line.points == 25)
    #expect(!line.concealed)
  }

  @Test func tokenRangesPointIntoNormalisedSource() throws {
    let line = try #require(parse("FF 2026/x 2222/y 6666/y ; 25 ; X"))
    let source = Array(line.variants[0].source)
    for token in line.variants[0].tokens {
      guard case .group(let spec, let range) = token else { continue }
      #expect(range.count == spec.count)
      #expect(range.upperBound <= source.count)
    }
  }
}

struct ParseErrorTests {
  @Test func missingSuitCoversTheGroup() throws {
    let found = errors("FF 2222 4444 6666 88 ; 25 ; X")
    let first = try #require(found.first)
    #expect(first.code == .missingSuit)
    #expect(first.range == 3..<7)
    #expect(found.filter { $0.code == .missingSuit }.count == 4)
  }

  @Test func missingSuitOnMatchingDragon() {
    #expect(errors("FF DD 2222/x 3333/x 4444/x ; 25 ; X").first?.code == .missingSuit)
  }

  @Test func badSuit() {
    let found = errors("FF 2222/q 4444/y 66/z 888/x ; 25 ; X")
    #expect(found.first?.code == .badSuit)
    #expect(errors("FF 2222/xy 4444/y 66/z 888/x ; 25 ; X").first?.code == .badSuit)
    #expect(errors("FF 2222/ 4444/y 66/z 888/x ; 25 ; X").first?.code == .badSuit)
  }

  @Test func badCharacter() throws {
    let found = errors("FF 2222/x 44Q4/y 66/z 888/x ; 25 ; X")
    let first = try #require(found.first)
    #expect(first.code == .badChar)
    #expect(first.range.count == 1)
    #expect(errors("FF /x 2222/y 4444/z 666/x ; 25 ; X").first?.code == .badChar)
  }

  @Test func thirteenTilesIsATileCountError() {
    let found = errors("FF 2222/x 4444/y 66/z 8/x ; 25 ; X")
    let first = found.first
    #expect(first?.code == .tileCount)
    #expect(first?.message.contains("13") == true)
    #expect(first?.message == "This hand has 13 tiles; a hand needs 14")
  }

  @Test func fifteenTilesIsATileCountError() {
    #expect(errors("FF 2222/x 4444/y 66/z 888/x ; 25 ; X").first?.message.contains("15") == true)
  }

  @Test func groupTooBig() {
    #expect(errors("NNNNNNN FF 22/x 33/x 44/x ; 25 ; X").first?.code == .groupTooBig)
    #expect(errors("2222222/x FF 33/x 44/x 55/x ; 25 ; X").first?.code == .groupTooBig)
  }

  @Test func eightFlowersAreAllowed() {
    #expect(parse("FFFFFFFF 222/x 333/x ; 25 ; X") != nil)
    #expect(errors("FFFFFFFFF 222/x 333/x ; 25 ; X").contains { $0.code == .groupTooBig })
  }

  @Test func badPoints() {
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 0 ; X").first?.code == .badPoints)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 501 ; X").first?.code == .badPoints)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; abc ; X").first?.code == .badPoints)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; +25 ; X").first?.code == .badPoints)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x").contains { $0.code == .badPoints })
  }

  @Test func pointsBoundariesParse() {
    #expect(parse("FF 2222/x 4444/y 66/z 88/x ; 1 ; X")?.points == 1)
    #expect(parse("FF 2222/x 4444/y 66/z 88/x ; 500 ; C")?.points == 500)
  }

  @Test func badExposure() {
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 25 ; Q").first?.code == .badExposure)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 25 ; x").first?.code == .badExposure)
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 25").contains { $0.code == .badExposure })
  }

  @Test func badFlag() {
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 25 ; X ; name ; wobble").first?.code == .badFlag)
    #expect(errors("FF 1111/x 2222/y 66/z 88/x ; 25 ; X ; n ; shift shift2").first?.code == .badFlag)
  }

  @Test func shiftWithoutNumbers() {
    let found = errors("NNNN EEE WWW SSSS ; 25 ; X ; Winds ; shift")
    #expect(found.first?.code == .shiftNoNumbers)
    #expect(errors("NNNN EEE WWW SSSS ; 25 ; X ; Winds ; shift2").first?.code == .shiftNoNumbers)
  }

  @Test func tooManyFields() {
    #expect(errors("FF 2222/x 4444/y 66/z 88/x ; 25 ; X ; n ; shift ; extra").contains { $0.code == .tooManyFields })
  }

  @Test func emptyInput() {
    #expect(errors("").first?.code == .empty)
    #expect(errors("   ").first?.code == .empty)
    #expect(errors(" ; 25 ; X").contains { $0.code == .empty })
    #expect(errors("FF 2222/x 4444/y 66/z 88/x | ; 25 ; X").contains { $0.code == .empty })
  }

  @Test func tooManyDistinctSuits() {
    #expect(errors("11/x 11/y 11/z 11/c 11/b 1/d 1/d ; 25 ; X").contains { $0.code == .badSuit })
  }

  @Test func tooManyOfTile() {
    // Six of the same pair-only tile can't exist: 6 plain North.
    #expect(errors("NN NN NN 222/x 3333/x 1/y ; 25 ; X").first?.code == .tooManyOfTile)
  }

  @Test func errorsAreSortedLeftToRight() {
    let found = errors("FF 2222 4444/q ; 0 ; Q")
    let starts = found.map(\.range.lowerBound)
    #expect(starts == starts.sorted())
    #expect(Set(found.map(\.code)).isSuperset(of: [.missingSuit, .badSuit, .badPoints, .badExposure]))
  }
}

struct VariantTests {
  @Test func eachVariantIsValidatedIndependently() throws {
    let line = try #require(
      parse("NNNNN EEEE 11111/x | SSSSS WWWW 11111/x ; 40 ; X ; Wind Quints ; shift"))
    #expect(line.variants.count == 2)
    #expect(line.variants[1].source == "SSSSS WWWW 11111/x")
    // The second variant has 13 tiles.
    let found = errors("NNNNN EEEE 11111/x | SSSSS WWW 11111/x ; 40 ; X")
    #expect(found.first?.code == .tileCount)
    // The bad variant's range lies inside the second variant.
    let text = "NNNNN EEEE 11111/x | SSSSS WWW 11111/x ; 40 ; X"
    let bar = text.distance(from: text.startIndex, to: text.firstIndex(of: "|")!)
    #expect((found.first?.range.lowerBound ?? 0) > bar)
  }

  @Test func triplePatternWithSupplyDroppingIsStillValid() throws {
    #expect(parse("2026/x 2026/y 2026/z DD/x ; 75 ; C") != nil)
  }

  @Test func nonDefaultIDAndSection() throws {
    guard case .success(let line) = Notation.parseLine(
      "FF 2222/x 4444/y 66/z 88/x ; 25 ; X", id: "custom", section: "Mine")
    else {
      Issue.record("expected success")
      return
    }
    #expect(line.id == "custom")
    #expect(line.section == "Mine")
    #expect(line.displayName == "Mine #1")
  }

  @Test func autoIDIsStable() throws {
    let a = try #require(parse("FF 2222/x 4444/y 66/z 88/x ; 25 ; X"))
    let b = try #require(parse("FF   2222/x 4444/y 66/z 88/x;25;X"))
    #expect(a.id == b.id)
    #expect(a.source == b.source)
  }

  @Test func hasNoJokerGroups() throws {
    let singles = try #require(parse("FF 11/x 22/x 33/x 44/x 55/x 66/x ; 50 ; C"))
    #expect(singles.hasNoJokerGroups)
    let normal = try #require(parse("FF 2222/x 4444/y 66/z 88/x ; 25 ; X"))
    #expect(!normal.hasNoJokerGroups)
  }
}

struct PracticeCardTests {
  @Test func parsesWithZeroErrorsAndHasExpectedShape() {
    let result = Notation.parseCardFile(PracticeCard.text)
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 37)
    #expect(result.name == "Practice Card")
    #expect(result.year == 2026)
    #expect(PracticeCard.card.lines.count == 37)
    #expect(PracticeCard.card.id == "practice-v1")
    #expect(PracticeCard.card.builtIn)
    #expect(
      PracticeCard.card.sections == [
        "Year", "2468", "Like Numbers", "Addition", "Quints", "Consecutive Run", "13579",
        "Winds & Dragons", "369", "Singles & Pairs",
      ])
  }

  @Test func everyVariantHasFourteenTiles() {
    for line in PracticeCard.card.lines {
      for variant in line.variants {
        #expect(variant.groups.reduce(0) { $0 + $1.count } == 14, "\(line.displayName)")
      }
    }
  }

  @Test func lineIDsAreUniqueAndNamesPresent() {
    let ids = PracticeCard.card.lines.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(PracticeCard.card.lines.allSatisfy { ($0.name ?? "").isEmpty == false })
  }

  @Test func roundTripOfEveryLine() {
    for line in PracticeCard.card.lines {
      let serialized = Notation.serialize(line)
      #expect(serialized == line.source)
      let again = Notation.parseLine(
        serialized, id: line.id, section: line.section, indexInSection: line.indexInSection)
      #expect(again == .success(line), "\(line.displayName)")
    }
  }

  @Test func cardFileRoundTrip() {
    let text = Notation.serialize(PracticeCard.card)
    let result = Notation.parseCardFile(text)
    #expect(result.errors.isEmpty)
    #expect(result.lines == PracticeCard.card.lines)
    #expect(result.name == "Practice Card")
    #expect(result.year == 2026)
    // Canonical text is a fixed point.
    let card = Notation.makeCard(from: result, id: "practice-v1", builtIn: true, createdAt: PracticeCard.card.createdAt)
    #expect(Notation.serialize(card) == text)
  }

  @Test func serializeLineFormats() throws {
    #expect(Notation.serialize(try #require(parse("FF 2222/x 4444/y 66/z 88/x;25;X"))) == "FF 2222/x 4444/y 66/z 88/x ; 25 ; X")
    #expect(
      Notation.serialize(try #require(parse("FF 2222/x 4444/y 66/z 88/x;25;C;Nice")))
        == "FF 2222/x 4444/y 66/z 88/x ; 25 ; C ; Nice")
    #expect(
      Notation.serialize(try #require(parse("FF 1111/x 2222/y 66/z 88/x;25;X;;shift2")))
        == "FF 1111/x 2222/y 66/z 88/x ; 25 ; X ;  ; shift2")
  }
}

struct CardFileTests {
  private let sample = """
    ! My Card
    !year 2027
    // a comment
    # First
    FF 2222/x 4444/y 66/z 88/x ; 25 ; X ; Good One

    FF 2222/x 4444/y 66/z ; 25 ; X ; Short
    # Second
    NNNN EEE WWW SSSS ; 25 ; X
    FF 2222 4444 6666 88 ; 25 ; X
    """

  @Test func reportsErrorsWithOneBasedLineNumbersAndKeepsValidLines() {
    let result = Notation.parseCardFile(sample)
    #expect(result.name == "My Card")
    #expect(result.year == 2027)
    #expect(result.lines.map(\.displayName) == ["Good One", "Second #1"])
    #expect(result.lines.map(\.section) == ["First", "Second"])
    #expect(result.errors.map(\.lineNumber) == [7, 10])
    #expect(result.errors[0].errors.first?.code == .tileCount)
    #expect(result.errors[1].errors.first?.code == .missingSuit)
    #expect(result.errors[1].text == "FF 2222 4444 6666 88 ; 25 ; X")
  }

  @Test func lineIDsAreStableAcrossReparse() {
    let a = Notation.parseCardFile(sample)
    let b = Notation.parseCardFile(sample)
    #expect(a.lines.map(\.id) == b.lines.map(\.id))
    #expect(a.lines[0].id.hasPrefix("L0_"))
    #expect(a.lines[1].id.hasPrefix("L1_"))
  }

  @Test func firstNameWinsAndSectionDefaultsToHands() {
    let result = Notation.parseCardFile("! One\n! Two\nNNNN EEE WWW SSSS ; 25 ; X\r\n")
    #expect(result.name == "One")
    #expect(result.lines.first?.section == "Hands")
    #expect(result.errors.isEmpty)
  }

  @Test func badYearIsReported() {
    let result = Notation.parseCardFile("!year abc\nNNNN EEE WWW SSSS ; 25 ; X")
    #expect(result.year == nil)
    #expect(result.errors.first?.lineNumber == 1)
    #expect(result.lines.count == 1)
  }

  @Test func emptyFile() {
    let result = Notation.parseCardFile("")
    #expect(result.lines.isEmpty && result.errors.isEmpty && result.name == nil)
  }

  @Test func idsSurviveInsertingALineAfterAnUnchangedOne() {
    let base = "NNNN EEE WWW SSSS ; 25 ; X\nFF 2222/x 4444/y 66/z 88/x ; 25 ; X"
    let extended = base + "\nFF 1111/x 2222/y 66/z 88/x ; 25 ; X"
    let a = Notation.parseCardFile(base)
    let b = Notation.parseCardFile(extended)
    #expect(Array(b.lines.prefix(2)).map(\.id) == a.lines.map(\.id))
  }
}

struct DescribeTests {
  private func describe(_ text: String) throws -> String {
    let line = try #require(parse(text))
    return Notation.describe(line.variants[0], shift: line.shift, concealed: line.concealed)
  }

  @Test func yearKongsMatchesTheSpecExample() throws {
    #expect(
      try describe("FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs")
        == "Pair of Flowers · 2026 in suit A (0 is Soap) · Kong of 2s in suit B · Kong of 6s in suit B · A and B are different suits."
    )
  }

  @Test func compassDragonsConcealed() throws {
    #expect(
      try describe("NEWS RR GG 00 FFFF ; 35 ; C ; Compass Dragons")
        == "One each of North, East, West and South · Pair of Red Dragons · Pair of Green Dragons · Pair of Soap · Kong of Flowers · Concealed — only the last tile may be called"
    )
  }

  @Test func shiftLine() throws {
    #expect(
      try describe("11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift")
        == "Pair of 1s in suit A · Pung of 2s in suit A · Kong of 3s in suit A · Pung of 4s in suit A · Pair of 5s in suit A · Numbers can be any consecutive/like set (example shown)"
    )
  }

  @Test func additionLineIgnoresOperators() throws {
    #expect(
      try describe("FF 3333/x + 4444/y = 7777/z ; 25 ; X ; Three Plus Four")
        == "Pair of Flowers · Kong of 3s in suit A · Kong of 4s in suit B · Kong of 7s in suit C · A, B and C are different suits."
    )
  }

  @Test func oddSinglesRunWithoutSoapIsSpaced() throws {
    #expect(
      try describe("13579/x 13579/y FFFF ; 40 ; C ; Odd Singles")
        == "1 3 5 7 9 in suit A · 1 3 5 7 9 in suit B · Kong of Flowers · A and B are different suits. · Concealed — only the last tile may be called"
    )
  }

  @Test func matchingDragonAndParityShift() throws {
    #expect(
      try describe("22/x 444/x 66/y 888/y DDDD/z ; 30 ; X ; Even Dragons")
        == "Pair of 2s in suit A · Pung of 4s in suit A · Pair of 6s in suit B · Pung of 8s in suit B · Kong of Dragons matching suit C · A, B and C are different suits."
    )
    let line = try #require(parse("1111/x 2222/x 33/y 44/y FF ; 25 ; X ; Name ; shift2"))
    #expect(
      Notation.describe(line.variants[0], shift: line.shift, concealed: false).hasSuffix(
        "Numbers can be any consecutive/like set, keeping odd/even (example shown)"))
  }

  @Test func fixedSuitsAndSingleTiles() throws {
    let text = try describe("1/c 22/c 333/c 4444/c NNN W ; 25 ; X")
    #expect(text.hasPrefix("Single 1 in Cracks · Pair of 2s in Cracks"))
    #expect(text.contains("Pung of North winds"))
    #expect(text.contains("Single West"))
    #expect(!text.contains("different suits"))
  }

  @Test func everyPracticeCardLineHasADescription() {
    for line in PracticeCard.card.lines {
      for variant in line.variants {
        let text = Notation.describe(variant, shift: line.shift, concealed: line.concealed)
        #expect(!text.isEmpty)
      }
    }
  }
}

struct InstantiateTests {
  @Test func assignmentsAreInjectiveAndAvoidFixedSuits() {
    let all = Instantiate.assignments(variables: [.x, .y], excluding: [])
    #expect(all.count == 6)
    #expect(all.allSatisfy { $0.x != $0.y })
    let withFixed = Instantiate.assignments(variables: [.x, .y], excluding: [.cracks])
    #expect(withFixed.count == 2)
    #expect(withFixed.allSatisfy { $0.x != .cracks && $0.y != .cracks })
    #expect(Instantiate.assignments(variables: [], excluding: []).count == 1)
    #expect(Instantiate.assignments(variables: [.x, .y, .z], excluding: []).count == 6)
  }

  @Test func supplyRules() {
    #expect(Instantiate.supplyViolation([(.dragon(.white), 1), (.dragon(.white), 1), (.dragon(.white), 1), (.dragon(.white), 2)]) == .dragon(.white))
    #expect(Instantiate.supplyViolation([(.dragon(.white), 3), (.dragon(.white), 1)]) == nil)
    #expect(Instantiate.supplyViolation([(.number(1, .dots), 7), (.number(1, .dots), 6)]) == .number(1, .dots))
    #expect(Instantiate.supplyViolation([(.flower, 8)]) == nil)
  }

  @Test func resolveShiftsAndRejectsOutOfRange() {
    let binding = Binding(x: .dots, y: nil, z: nil, k: 2)
    #expect(Instantiate.resolve(.number(3, .variable(.x)), binding: binding) == .number(5, .dots))
    #expect(Instantiate.resolve(.number(8, .variable(.x)), binding: binding) == nil)
    #expect(Instantiate.resolve(.matchingDragon(.variable(.x)), binding: binding) == .dragon(.white))
    #expect(Instantiate.resolve(.fixed(.flower), binding: binding) == .flower)
    #expect(Instantiate.resolve(.number(3, .variable(.y)), binding: binding) == nil)
  }
}
