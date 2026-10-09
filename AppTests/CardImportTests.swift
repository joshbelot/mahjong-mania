import MahjongCore
import Testing

@testable import MahjongMania

struct CardImportTests {
  @Test func practiceCardTextImportsAllThirtySevenHands() {
    let report = CardImport.check(PracticeCard.text)
    #expect(report.validCount == 37)
    #expect(report.problems.isEmpty)
    #expect(report.summary == "37 hands \u{2713}")
    #expect(report.importTitle == "Import 37 hands")
    #expect(report.name == "Practice Card")
    #expect(report.year == 2026)
    #expect(report.problemSummary == nil)
  }

  @Test func problemsAreReportedWithTheirLineNumbers() {
    let text = """
      ! Mixed
      # Year
      FF 2026/x 2222/y 6666/y ; 25 ; X ; Good
      FF 2026 ; 25 ; X ; No suits
      NNNN EEE WWW SSSS ; 25 ; X ; Winds
      """
    let report = CardImport.check(text)
    #expect(report.validCount == 2)
    #expect(report.problems.count == 1)
    #expect(report.problems[0].lineNumber == 4)
    #expect(report.summary == "2 hands \u{2713}")
    #expect(report.problemSummary == "1 line has a problem and will be skipped")
  }

  @Test func emptyOrGarbageTextHasNoHands() {
    #expect(CardImport.check("").summary == "No hands found")
    let garbage = CardImport.check("hello world")
    #expect(garbage.validCount == 0)
    #expect(garbage.problems.count == 1)
    #expect(garbage.importTitle == "Import hands")
    #expect(garbage.body.isEmpty)
  }

  @Test func singularSummary() {
    let report = CardImport.check("NNNN EEE WWW SSSS ; 25 ; X")
    #expect(report.summary == "1 hand \u{2713}")
    #expect(report.importTitle == "Import 1 hand")
  }

  @Test func bodyHasNoHeaderLines() {
    let report = CardImport.check(PracticeCard.text)
    #expect(!report.body.contains("!"))
    #expect(report.body.hasPrefix("# Year\n"))
  }

  @Test func newCardTextParsesBackWithNameAndYear() {
    let report = CardImport.check(PracticeCard.text)
    let text = CardImport.newCardText(name: "Mine", report: report)
    let result = Notation.parseCardFile(text)
    #expect(result.name == "Mine")
    #expect(result.year == 2026)
    #expect(result.lines.count == 37)
    #expect(result.errors.isEmpty)
  }

  @Test func bodyCanBeAppendedToAnotherCard() {
    let existing = "! Mine\n# Hands\nNNNN EEE WWW SSSS ; 25 ; X ; Winds\n"
    let report = CardImport.check(PracticeCard.text)
    let combined = existing + report.body
    let result = Notation.parseCardFile(combined)
    #expect(result.name == "Mine")
    #expect(result.lines.count == 38)
    #expect(result.errors.isEmpty)
  }

  @Test func cardNamePrefersTypedThenFileThenFallback() {
    let named = CardImport.check("! From File\nNNNN EEE WWW SSSS ; 25 ; X")
    #expect(CardImport.cardName(typed: "  Typed  ", report: named) == "Typed")
    #expect(CardImport.cardName(typed: "", report: named) == "From File")
    let unnamed = CardImport.check("NNNN EEE WWW SSSS ; 25 ; X")
    #expect(CardImport.cardName(typed: "   ", report: unnamed) == "Imported card")
    #expect(CardImport.cardName(typed: "A\nB", report: unnamed) == "A B")
  }

  @Test func windowsLineEndingsAreAccepted() {
    let text = "! Win\r\n# Year\r\nNNNN EEE WWW SSSS ; 25 ; X\r\n"
    let report = CardImport.check(text)
    #expect(report.validCount == 1)
    #expect(report.problems.isEmpty)
  }
}

@MainActor
struct CardImportStoreTests {
  @Test func importingIntoANewCardCreatesIt() throws {
    let stores = AppStores.inMemory(persistDelay: .milliseconds(10))
    let report = CardImport.check(PracticeCard.text)
    let name = CardImport.cardName(typed: "Imported", report: report)
    let record = stores.cards.createCard(
      name: name, year: report.year, text: CardImport.newCardText(name: name, report: report))
    let card = try #require(stores.cards.card(id: record.id))
    #expect(card.name == "Imported")
    #expect(card.year == 2026)
    #expect(card.lines.count == 37)
    #expect(stores.cards.cards.count == 2)
  }

  @Test func importingIntoAnExistingCardAppends() throws {
    let stores = AppStores.inMemory(persistDelay: .milliseconds(10))
    let record = stores.cards.createCard(name: "Mine")
    let report = CardImport.check(PracticeCard.text)
    stores.cards.append(text: report.body, to: record.id)
    let card = try #require(stores.cards.card(id: record.id))
    #expect(card.lines.count == 37)
    #expect(card.name == "Mine")
  }
}
