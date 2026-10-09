import MahjongCore
import Testing

@testable import MahjongMania

private func model(_ notation: String, sections: [String] = ["Year"]) -> LineEditorModel {
  var model = LineEditorModel(availableSections: sections)
  model.notation = notation
  return model
}

struct LineEditorModelTests {
  @Test func blankFormStartsEmptyWithDefaults() {
    let blank = LineEditorModel(availableSections: ["Year", "2468"])
    #expect(blank.sectionChoice == .existing("2468"))
    #expect(blank.points == 25)
    #expect(blank.concealed == false)
    #expect(blank.shift == .none)
    #expect(blank.canSave == false)
    guard case .empty = blank.status else {
      Issue.record("Expected the empty status")
      return
    }
  }

  @Test func cardWithoutSectionsStartsWithANewSection() {
    let blank = LineEditorModel(availableSections: [])
    #expect(blank.sectionChoice == .new)
    #expect(blank.effectiveSection == "Hands")
  }

  @Test func validNotationProducesALine() {
    var form = model("FF 2026/x 2222/y 6666/y")
    form.name = "Year Kongs"
    form.points = 30
    form.concealed = true
    guard case .valid(let line) = form.status else {
      Issue.record("Expected a valid line")
      return
    }
    #expect(line.points == 30)
    #expect(line.concealed)
    #expect(line.name == "Year Kongs")
    #expect(line.section == "Year")
    #expect(line.variants.count == 1)
    #expect(form.canSave)
  }

  @Test func composedTextMatchesTheCanonicalForm() {
    var form = model("FF 1111/x 11/y 1111/z DD/x")
    form.shift = .consecutive
    form.name = "Like Sandwich"
    #expect(form.composedText == "FF 1111/x 11/y 1111/z DD/x ; 25 ; X ; Like Sandwich ; shift")
    guard case .valid(let line) = form.status else {
      Issue.record("Expected a valid line")
      return
    }
    #expect(Notation.serialize(line) == form.composedText)
  }

  @Test func shiftWithoutNameStillParses() {
    var form = model("FF 1111/x 11/y 1111/z DD/x")
    form.shift = .parity
    #expect(form.composedText == "FF 1111/x 11/y 1111/z DD/x ; 25 ; X ;  ; shift2")
    #expect(form.canSave)
  }

  @Test func wrongTileCountIsReportedWithARangeOverTheNotation() {
    let form = model("FF 2026/x 2222/y")
    guard case .invalid(let problems) = form.status else {
      Issue.record("Expected problems")
      return
    }
    #expect(problems.count == 1)
    #expect(problems[0].message.contains("10 tiles"))
    #expect(problems[0].range == 0..<16)
    #expect(form.canSave == false)
  }

  @Test func badSuitPointsAtTheSuitLetter() {
    let form = model("FF 2222/q")
    guard case .invalid(let problems) = form.status else {
      Issue.record("Expected problems")
      return
    }
    #expect(problems.first?.range == 7..<9)
    #expect(LineEditorModel.marker(for: 7..<9) == "       ^~")
  }

  @Test func markerAlwaysHasAtLeastACaret() {
    #expect(LineEditorModel.marker(for: 0..<0) == "^")
    #expect(LineEditorModel.marker(for: 3..<4) == "   ^")
    #expect(LineEditorModel.marker(for: 2..<6) == "  ^~~~")
  }

  @Test func shiftFlagWithoutNumbersIsAGeneralProblem() {
    var form = model("NNNN EEE WWW SSSS")
    form.shift = .consecutive
    guard case .invalid(let problems) = form.status else {
      Issue.record("Expected problems")
      return
    }
    #expect(problems.count == 1)
    #expect(problems[0].range == nil)
  }

  @Test func semicolonsAreRejectedWithTheirPosition() {
    let form = model("FF 2222/x ; 25")
    guard case .invalid(let problems) = form.status else {
      Issue.record("Expected problems")
      return
    }
    #expect(problems[0].range == 10..<11)
  }

  @Test func lineBreaksAreTreatedAsSpaces() {
    let form = model("FF 2026/x\n2222/y 6666/y")
    #expect(form.cleanNotation == "FF 2026/x 2222/y 6666/y")
    #expect(form.canSave)
  }

  @Test func nameCannotInjectFields() {
    var form = model("FF 2026/x 2222/y 6666/y")
    form.name = "A; B\nC"
    #expect(form.cleanName == "A  B C")
    guard case .valid(let line) = form.status else {
      Issue.record("Expected a valid line")
      return
    }
    #expect(line.name == "A  B C")
  }

  @Test func newSectionNeedsAName() {
    var form = model("FF 2026/x 2222/y 6666/y")
    form.sectionChoice = .new
    #expect(form.newSectionName.isEmpty)
    #expect(form.sectionProblem != nil)
    #expect(form.canSave == false)
    form.newSectionName = "  Mine  "
    #expect(form.effectiveSection == "Mine")
    #expect(form.sectionProblem == nil)
    #expect(form.validLine?.section == "Mine")
  }

  // MARK: Key row

  @Test func tileAndSuitKeysAppend() {
    var form = model("")
    form.press(.text("F"))
    form.press(.text("F"))
    form.press(.space)
    form.press(.text("2"))
    form.press(.text("/x"))
    #expect(form.notation == "FF 2/x")
  }

  @Test func operatorKeysAddSpacing() {
    var form = model("FF 2222/x")
    form.press(.text("+"))
    form.press(.text("3"))
    #expect(form.notation == "FF 2222/x + 3")
    form.press(.space)
    form.press(.text("|"))
    #expect(form.notation == "FF 2222/x + 3 | ")
  }

  @Test func operatorFirstDoesNotAddALeadingSpace() {
    var form = model("")
    form.press(.text("|"))
    #expect(form.notation == "| ")
  }

  @Test func backspaceRemovesOneCharacterAndStopsAtEmpty() {
    var form = model("FF")
    form.press(.backspace)
    #expect(form.notation == "F")
    form.press(.backspace)
    form.press(.backspace)
    #expect(form.notation.isEmpty)
  }

  @Test func keyRowCoversEverythingInTheSpec() {
    let all = Set(LineEditorModel.tileKeys + LineEditorModel.suitKeys + LineEditorModel.operatorKeys)
    for key in ["F", "N", "E", "W", "S", "R", "G", "0", "D", "1", "9", "/x", "/y", "/z", "/c", "/b", "/d", "|", "+", "="] {
      #expect(all.contains(key))
    }
  }

  // MARK: Editing existing lines

  @Test func everyPracticeLineRoundTripsThroughTheForm() {
    for line in PracticeCard.card.lines {
      let form = LineEditorModel(card: PracticeCard.card, editing: line)
      guard case .valid(let result) = form.status else {
        Issue.record("\(line.displayName) did not validate")
        continue
      }
      #expect(result.source == line.source)
      #expect(result.section == line.section)
    }
  }

  @Test func editingFillsTheFields() {
    let line = PracticeCard.card.lines.first { $0.name == "Like Sandwich" }
    guard let line else {
      Issue.record("Missing line")
      return
    }
    let form = LineEditorModel(card: PracticeCard.card, editing: line)
    #expect(form.name == "Like Sandwich")
    #expect(form.shift == .consecutive)
    #expect(form.sectionChoice == .existing("Like Numbers"))
    #expect(form.availableSections == PracticeCard.card.sections)
  }

  @Test func multiVariantLinesKeepTheirBars() {
    let line = PracticeCard.card.lines.first { $0.variants.count > 1 }
    guard let line else {
      Issue.record("Missing multi-variant line")
      return
    }
    let form = LineEditorModel(card: PracticeCard.card, editing: line)
    #expect(form.notation.contains(" | "))
    #expect(form.validLine?.variants.count == line.variants.count)
  }
}
