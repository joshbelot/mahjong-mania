import XCTest

/// The Practice Card file text, copied from `PracticeCard.text` (the UI test bundle cannot import
/// MahjongCore). `testFixtureHas37Lines` guards against accidental edits.
enum PracticeCardFixture {
  static let text = """
    ! Practice Card
    !year 2026
    # Year
    FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs
    2222/x 000 222/y 6666/z ; 25 ; X ; Soap Year
    FF NEWS 2026/x 2026/y ; 50 ; C ; Compass Year
    2026/x 2026/y 2026/z DD/x ; 75 ; C ; Triple Year
    # 2468
    222/x 4444/x 666/x 8888/x ; 25 ; X ; Even Climb
    FF 2222/x 44/y 66/y 8888/x ; 25 ; X ; Even Bookends
    22/x 444/x 66/y 888/y DDDD/z ; 30 ; X ; Even Dragons
    FFFF 2468/x 222/y 888/z ; 25 ; X ; Even Spread
    FF 22/x 44/x 66/x 88/x 2468/y ; 50 ; C ; Even Pairs
    # Like Numbers
    FF 1111/x 11/y 1111/z DD/x ; 25 ; X ; Like Sandwich ; shift
    1111/x 1111/y 111/z FFF ; 25 ; X ; Like Trio ; shift
    FF 11/x 11/y 11/z DD/x DD/y DD/z ; 50 ; C ; Like Pairs ; shift
    # Addition
    FF 3333/x + 4444/y = 7777/z ; 25 ; X ; Three Plus Four
    FF 1111/x + 5555/x = 6666/x ; 30 ; X ; One Plus Five
    22/x + 55/x = 77/x 22/y + 55/y = 77/y FF ; 50 ; C ; Double Sum
    # Quints
    FFFF 11111/x 22222/y ; 45 ; X ; Quint Steps ; shift
    NNNNN EEEE 11111/x | SSSSS WWWW 11111/x ; 40 ; X ; Wind Quints ; shift
    11111/x DDDD/x 11111/y ; 45 ; X ; Like Quints ; shift
    # Consecutive Run
    11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift
    FFF 1111/x 2222/y 333/z ; 25 ; X ; Three Suit Run ; shift
    111/x 2222/x 333/y 4444/y ; 25 ; X ; Two Suit Run ; shift
    FF 1/x 22/x 333/x 4444/x 55/x ; 30 ; X ; Staircase ; shift
    112233/x 445566/y FF ; 50 ; C ; Pair Ladder ; shift
    # 13579
    11/x 333/x 5555/x 777/x 99/x ; 25 ; X ; Odd Climb
    FFFF 1111/x 9999/y 55/z ; 25 ; X ; Odd Ends
    111/x 33/x 555/y 77/y 9999/z ; 30 ; X ; Odd Spread
    13579/x 13579/y FFFF ; 40 ; C ; Odd Singles
    11/x 33/x 55/x 77/x 99/x 11/y 99/y ; 50 ; C ; Odd Pairs
    # Winds & Dragons
    NNNN EEE WWW SSSS ; 25 ; X ; Four Winds
    FF RRR GGG 000 NNN | FF RRR GGG 000 EEE | FF RRR GGG 000 WWW | FF RRR GGG 000 SSS ; 30 ; X ; Dragons And A Wind
    NNN SSS DDDD/x DDDD/y ; 25 ; X ; North South Dragons
    NEWS RR GG 00 FFFF ; 35 ; C ; Compass Dragons
    # 369
    333/x 666/x 9999/x DDDD/x ; 25 ; X ; Threes In One
    FF 3333/x 6666/y 9999/z ; 25 ; X ; Threes Across
    FF 33/x 66/x 99/x 33/y 66/y 99/y ; 50 ; C ; Threes In Pairs
    # Singles & Pairs
    NN EE WW SS 11/x 11/y 11/z ; 50 ; C ; Winds And Likes ; shift
    FF 11/x 22/x 33/x 44/x 55/x 66/x ; 50 ; C ; Pair Run ; shift
    """

  static var handCount: Int {
    text.split(separator: "\n").filter { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      return !trimmed.isEmpty && !trimmed.hasPrefix("!") && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("//")
    }.count
  }
}

/// Cards tab flows: import the Practice Card through the pasteboard, duplicate it, edit a line with live
/// errors. Every step attaches a screenshot (light + dark for the import flow).
@MainActor
final class CardsTests: XCTestCase {
  private func launch(dark: Bool) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData"]
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()
    return app
  }

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func button(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.buttons.matching(identifier: id).firstMatch
  }

  /// One line listing the identifiers and labels on screen, for failure messages.
  private func screenSummary(_ app: XCUIApplication) -> String {
    let lines = app.debugDescription.components(separatedBy: "\n")
      .filter { $0.contains("identifier:") || $0.contains("label:") }
      .map { $0.trimmingCharacters(in: .whitespaces) }
    return String(lines.joined(separator: " | ").prefix(3500))
  }

  @discardableResult
  private func waitFor(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> XCUIElement {
    let item = element(app, id)
    if !item.waitForExistence(timeout: timeout) {
      XCTFail("Missing element \(id). Screen: \(screenSummary(app))")
    }
    return item
  }

  /// Swipes the screen up until the element is on screen (SwiftUI scroll views may not expose far-off content).
  @discardableResult
  private func reveal(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    let item = waitFor(app, id)
    var swipes = 0
    while !item.isHittable && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    return item
  }

  private func openCards(_ app: XCUIApplication) {
    let tab = app.tabBars.buttons["Cards"]
    XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing Cards tab")
    tab.tap()
    waitFor(app, "cards.import")
  }

  /// Fills the import text area: system paste button first, typing as a fallback.
  private func fillImportText(_ app: XCUIApplication) {
    UIPasteboard.general.string = PracticeCardFixture.text
    let field = waitFor(app, "import.text")
    let paste = element(app, "import.paste")
    if paste.waitForExistence(timeout: 3) {
      paste.tap()
    }
    let deadline = Date().addingTimeInterval(8)
    while Date() < deadline {
      if let value = field.value as? String, value.contains("Practice Card") { return }
      Thread.sleep(forTimeInterval: 0.5)
    }
    field.tap()
    field.typeText(PracticeCardFixture.text)
  }

  func testFixtureHas37Lines() {
    XCTAssertEqual(PracticeCardFixture.handCount, 37)
  }

  private func importAndEdit(dark: Bool) {
    let app = launch(dark: dark)
    let scheme = dark ? "dark" : "light"
    openCards(app)
    attach("cards-list-\(scheme)")

    element(app, "cards.import").tap()
    fillImportText(app)

    let name = waitFor(app, "import.name")
    name.tap()
    name.typeText("Imported\n")

    element(app, "import.check").tap()
    let summary = waitFor(app, "import.summary")
    XCTAssertEqual(summary.label, "37 hands \u{2713}")
    app.swipeUp()
    attach("cards-import-checked-\(scheme)")

    element(app, "import.confirm").tap()
    XCTAssertTrue(app.navigationBars["Imported"].waitForExistence(timeout: 10), "Imported card did not open")
    let firstRow = waitFor(app, "line.row.0")
    attach("cards-detail-\(scheme)")

    firstRow.tap()
    waitFor(app, "line.pattern")
    attach("cards-line-detail-\(scheme)")
    let trySuits = element(app, "line.trySuits")
    if trySuits.exists && trySuits.isHittable {
      trySuits.tap()
      attach("cards-line-detail-suits-\(scheme)")
    }
    reveal(app, "line.practise")
    attach("cards-line-detail-bottom-\(scheme)")

    waitFor(app, "line.edit").tap()
    let notation = waitFor(app, "editor.notation")
    waitFor(app, "editor.valid")
    attach("cards-editor-valid-\(scheme)")

    notation.tap()
    appendToNotation(app, notation, keys: ["9", "9"])
    waitFor(app, "editor.error")
    XCTAssertFalse(button(app, "editor.save").isEnabled, "Save must be disabled while there are errors")
    attach("cards-editor-error-\(scheme)")

    deleteFromNotation(app, notation, count: 2)
    waitFor(app, "editor.valid")
    XCTAssertTrue(button(app, "editor.save").isEnabled)
    attach("cards-editor-fixed-\(scheme)")
  }

  /// Uses the key row above the keyboard when it is shown, and the keyboard otherwise.
  private func appendToNotation(_ app: XCUIApplication, _ field: XCUIElement, keys: [String]) {
    let first = element(app, "key.\(keys[0])")
    if first.waitForExistence(timeout: 3) && first.isHittable {
      for key in keys { element(app, "key.\(key)").tap() }
    } else {
      field.typeText(keys.joined())
    }
  }

  private func deleteFromNotation(_ app: XCUIApplication, _ field: XCUIElement, count: Int) {
    let delete = element(app, "key.delete")
    if delete.exists && delete.isHittable {
      for _ in 0..<count { delete.tap() }
    } else {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
    }
  }

  func testImportAndEditLight() { importAndEdit(dark: false) }
  func testImportAndEditDark() { importAndEdit(dark: true) }

  func testDuplicatePracticeCardEditLineAndSave() {
    let app = launch(dark: false)
    openCards(app)
    waitFor(app, "cards.row.practice-v1").tap()
    waitFor(app, "card.builtInBanner")
    attach("cards-builtin-banner-light")
    waitFor(app, "card.duplicate").tap()
    XCTAssertTrue(
      app.navigationBars["Practice Card copy"].waitForExistence(timeout: 10), "Duplicate did not open")
    XCTAssertFalse(element(app, "card.builtInBanner").exists, "The copy must be editable")

    waitFor(app, "line.row.0").tap()
    waitFor(app, "line.pattern")
    waitFor(app, "line.edit").tap()

    let notation = waitFor(app, "editor.notation")
    notation.tap()
    appendToNotation(app, notation, keys: ["9", "9"])
    waitFor(app, "editor.error")
    XCTAssertFalse(button(app, "editor.save").isEnabled)
    deleteFromNotation(app, notation, count: 2)
    waitFor(app, "editor.valid")

    let nameField = reveal(app, "editor.name")
    nameField.tap()
    nameField.typeText(" Edited")

    let save = button(app, "editor.save")
    XCTAssertTrue(save.isEnabled)
    save.tap()
    let edited = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Year Kongs Edited")).firstMatch
    XCTAssertTrue(
      edited.waitForExistence(timeout: 10),
      "The edited hand should show in the card detail. Screen: \(screenSummary(app))")
    waitFor(app, "line.row.0")
    attach("cards-edited-detail-light")
  }

  func testPractiseThisHandOpensTheHelper() {
    let app = launch(dark: false)
    openCards(app)
    waitFor(app, "cards.row.practice-v1").tap()
    waitFor(app, "line.row.1").tap()
    waitFor(app, "line.pattern")
    attach("cards-line-detail-builtin-light")
    reveal(app, "line.practise").tap()
    XCTAssertTrue(app.navigationBars["Helper"].waitForExistence(timeout: 10), "Helper tab did not open")
  }
}
