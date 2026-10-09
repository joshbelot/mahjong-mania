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

  @Test func addingAppendsToAnExistingSection() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 30 ; X ; Extra")
    let result = reparsed(CardEditing.text(adding: line, to: card))
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
    let result = reparsed(CardEditing.text(adding: line, to: card))
    #expect(result.lines.count == 38)
    #expect(result.lines.last?.section == "Mine")
  }

  @Test func replacingKeepsThePosition() throws {
    let target = try #require(card.lines.first { $0.name == "Even Climb" })
    let index = try #require(card.lines.firstIndex(of: target))
    let line = parsedLine("FF 2222/x 44/y 66/y 8888/x ; 40 ; C ; Even Climb Edited", section: target.section)
    let result = reparsed(CardEditing.text(replacing: target.id, with: line, in: card))
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 37)
    #expect(result.lines[index].name == "Even Climb Edited")
    #expect(result.lines[index].points == 40)
    #expect(result.lines[index].concealed)
  }

  @Test func replacingIntoAnotherSectionMovesTheLine() throws {
    let target = try #require(card.lines.first { $0.name == "Even Climb" })
    let line = parsedLine("FF 2222/x 44/y 66/y 8888/x ; 25 ; X ; Even Climb", section: "Year")
    let result = reparsed(CardEditing.text(replacing: target.id, with: line, in: card))
    #expect(result.lines.count == 37)
    #expect(result.lines.filter { $0.section == "Year" }.count == 5)
    #expect(result.lines.filter { $0.section == "2468" }.count == 4)
  }

  @Test func replacingAMissingLineAppendsIt() {
    let line = parsedLine("FF 2026/x 2222/y 6666/y ; 25 ; X ; Late")
    let result = reparsed(CardEditing.text(replacing: "nope", with: line, in: card))
    #expect(result.lines.count == 38)
  }

  @Test func removingDropsOnlyThatLine() throws {
    let target = try #require(card.lines.first { $0.name == "Triple Year" })
    let result = reparsed(CardEditing.text(removing: target.id, from: card))
    #expect(result.errors.isEmpty)
    #expect(result.lines.count == 36)
    #expect(!result.lines.contains { $0.name == "Triple Year" })
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
    stores.cards.updateText(id: copy.id, text: CardEditing.text(replacing: card.lines[0].id, with: line, in: card))

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
    let card = try #require(stores.cards.card(id: record.id))
    stores.cards.updateText(id: record.id, text: CardEditing.text(adding: line, to: card))
    let saved = try #require(stores.cards.card(id: record.id))
    #expect(saved.lines.count == 1)
    #expect(saved.lines[0].section == "Hands")
    #expect(saved.name == "Mine")
  }
}
