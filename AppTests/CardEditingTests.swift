import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private func parsedLine(_ text: String, section: String = "Year") -> CardLine {
  switch Notation.parseLine(text, id: nil, section: section) {
  case .success(let line): return line
  case .failure: preconditionFailure("Test line does not parse: \(text)")
  }
}

private func reparsed(_ text: String) -> CardFileParseResult {
  Notation.parseCardFile(text)
}

struct CardEditingTests {
  private let card = PracticeCard.card
  private var source: String { Notation.serialize(card) }

  @Test func addingAppendsToAnExistingSection() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 30 ; X ; Extra")
    let result = reparsed(CardEditing.text(adding: line, to: source))
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 38)
    #expect(result.name == "Practice Card")
    #expect(result.year == 2026)
    let year = result.lines.filter { $0.section == "Year" }
    #expect(year.count == 5)
    #expect(year.last?.name == "Extra")
  }

  @Test func addingInANewSectionCreatesIt() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 30 ; X ; Extra", section: "Mine")
    let result = reparsed(CardEditing.text(adding: line, to: source))
    #expect(result.lines.count == 38)
    #expect(result.lines.last?.section == "Mine")
  }

  @Test func replacingKeepsThePosition() throws {
    let target = try #require(card.lines.first { $0.name == "Even Climb" })
    let index = try #require(card.lines.firstIndex(of: target))
    let line = parsedLine("FF 2222/x 44/y 66/y 8888/x ; 40 ; C ; Even Climb Edited", section: target.section)
    let result = reparsed(CardEditing.text(replacing: target.id, with: line, in: source))
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 37)
    #expect(result.lines[index].name == "Even Climb Edited")
    #expect(result.lines[index].points == 40)
    #expect(result.lines[index].concealed)
  }

  @Test func replacingIntoAnotherSectionMovesTheLine() throws {
    let target = try #require(card.lines.first { $0.name == "Even Climb" })
    let line = parsedLine("FF 2222/x 44/y 66/y 8888/x ; 25 ; X ; Even Climb", section: "Year")
    let result = reparsed(CardEditing.text(replacing: target.id, with: line, in: source))
    #expect(result.lines.count == 37)
    #expect(result.lines.filter { $0.section == "Year" }.count == 5)
    #expect(result.lines.filter { $0.section == "2468" }.count == 4)
  }

  @Test func replacingAMissingLineAppendsIt() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 25 ; X ; Late")
    let result = reparsed(CardEditing.text(replacing: "nope", with: line, in: source))
    #expect(result.lines.count == 38)
  }

  @Test func removingDropsOnlyThatLine() throws {
    let target = try #require(card.lines.first { $0.name == "Triple Year" })
    let result = reparsed(CardEditing.text(removing: target.id, from: source))
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 36)
    #expect(!result.lines.contains { $0.name == "Triple Year" })
  }

  // MARK: Hand-written text survives edits (a user's comments and not-yet-valid lines)

  private let handWritten = """
    ! Mine
    !year 2027
    // copied from the club card
    # First
    FF 2222/x 4444/y 66/z 88/x ; 25 ; X ; Good One
    // half typed, fix me later
    FF 2222/x 4444/y 66/z ; 25 ; X ; Short

    # Second
    NNNN EEE WWW SSSS ; 25 ; X ; Winds
    FF 2468 ; 30 ; C ; Not valid yet
    """

  @Test func editingAHandKeepsCommentsInvalidLinesAndOrder() throws {
    let parsed = Notation.parseCardFile(handWritten)
    let target = try #require(parsed.lines.first { $0.name == "Winds" })
    let line = parsedLine("NNNN EEE WWW SSSS ; 40 ; C ; Winds", section: "Second")
    let edited = CardEditing.text(replacing: target.id, with: line, in: handWritten)
    #expect(
      edited
        == handWritten.replacingOccurrences(
          of: "NNNN EEE WWW SSSS ; 25 ; X ; Winds", with: "NNNN EEE WWW SSSS ; 40 ; C ; Winds"))
    #expect(Notation.parseCardFile(edited).lines.map(\.points) == [25, 40])
  }

  @Test func removingAHandKeepsEverythingElse() throws {
    let parsed = Notation.parseCardFile(handWritten)
    let target = try #require(parsed.lines.first { $0.name == "Good One" })
    let edited = CardEditing.text(removing: target.id, from: handWritten)
    #expect(edited.contains("// copied from the club card"))
    #expect(edited.contains("// half typed, fix me later"))
    #expect(edited.contains("FF 2222/x 4444/y 66/z ; 25 ; X ; Short"))
    #expect(edited.contains("FF 2468 ; 30 ; C ; Not valid yet"))
    #expect(!edited.contains("Good One"))
    #expect(Notation.parseCardFile(edited).lines.map(\.name) == ["Winds"])
  }

  @Test func addingGoesAfterTheSectionsLastLineNotAtTheEnd() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 30 ; X ; Extra", section: "First")
    let edited = CardEditing.text(adding: line, to: handWritten)
    let rows = edited.components(separatedBy: "\n")
    let extra = rows.firstIndex { $0.hasSuffix("; Extra") }
    let second = rows.firstIndex(of: "# Second")
    #expect(extra != nil && second != nil && extra! < second!)
    #expect(rows[extra! - 1] == "FF 2222/x 4444/y 66/z ; 25 ; X ; Short")
    #expect(edited.contains("FF 2468 ; 30 ; C ; Not valid yet"))
    #expect(edited.contains("// half typed, fix me later"))
  }

  @Test func addingInANewSectionAppendsItAndKeepsTheRest() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 30 ; X ; Extra", section: "Third")
    let edited = CardEditing.text(adding: line, to: handWritten)
    #expect(edited.hasPrefix(handWritten))
    #expect(edited.hasSuffix("# Third\nFF 2026/x 2222/y 6666/y ; 30 ; X ; Extra\n"))
  }

  @Test func movingAHandToAnotherSectionLeavesTheTextAround() throws {
    let parsed = Notation.parseCardFile(handWritten)
    let target = try #require(parsed.lines.first { $0.name == "Good One" })
    let line = parsedLine("FF 2222/x 4444/y 66/z 88/x ; 25 ; X ; Good One", section: "Second")
    let edited = CardEditing.text(replacing: target.id, with: line, in: handWritten)
    let result = Notation.parseCardFile(edited)
    #expect(result.lines.map(\.section) == ["Second", "Second"])
    #expect(edited.contains("// half typed, fix me later"))
    #expect(edited.contains("FF 2468 ; 30 ; C ; Not valid yet"))
  }

  @Test func addingToAnEmptyNewCardWorks() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 25 ; X", section: "Hands")
    let edited = CardEditing.text(adding: line, to: "! Mine\n")
    #expect(edited == "! Mine\nFF 2026/x 2222/y 6666/y ; 25 ; X\n")
  }

  @Test func sharingEmitsTheCanonicalCardFile() {
    let text = Notation.serialize(card)
    #expect(text.hasPrefix("! Practice Card\n!year 2026\n# Year\n"))
    let result = reparsed(text)
    #expect(result.lines.count == 37)
    #expect(result.lines.map(\.source) == card.lines.map(\.source))
  }
}

@MainActor
struct CardsFlowTests {
  @Test func duplicateEditSaveReloadsInTheStore() throws {
    let stores = AppStores.inMemory(persistDelay: .milliseconds(10))
    let copy = try #require(stores.cards.duplicate(cardID: PracticeCard.card.id))
    let card = try #require(stores.cards.card(id: copy.id))
    #expect(card.lines.count == 37)
    #expect(card.builtIn == false)

    var form = LineEditorModel(card: card, editing: card.lines[0])
    form.name = "Year Kongs Edited"
    form.points = 30
    let line = try #require(form.validLine)
    stores.cards.updateText(id: copy.id, text: CardEditing.text(replacing: card.lines[0].id, with: line, in: try #require(stores.cards.record(id: copy.id)).text))

    let edited = try #require(stores.cards.card(id: copy.id))
    #expect(edited.lines.count == 37)
    #expect(edited.lines[0].name == "Year Kongs Edited")
    #expect(edited.lines[0].points == 30)
    #expect(stores.cards.problems(in: copy.id).isEmpty)
  }

  @Test func newCardGetsLinesOneByOne() throws {
    let stores = AppStores.inMemory(persistDelay: .milliseconds(10))
    let record = stores.cards.createCard(name: "Mine")
    var form = LineEditorModel(availableSections: [])
    form.notation = "FF 2026/x 2222/y 6666/y"
    let line = try #require(form.validLine)
    let source = try #require(stores.cards.record(id: record.id)).text
    stores.cards.updateText(id: record.id, text: CardEditing.text(adding: line, to: source))
    let saved = try #require(stores.cards.card(id: record.id))
    #expect(saved.lines.count == 1)
    #expect(saved.lines[0].section == "Hands")
    #expect(saved.name == "Mine")
  }
}
