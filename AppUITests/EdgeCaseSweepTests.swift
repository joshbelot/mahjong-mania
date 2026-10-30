import XCTest

/// SPEC §19.4 steps 4 and 5: awkward data (a 3-player table, very long and emoji names, a 200-hand night, an
/// empty card with a long name, a night whose card was deleted) on every screen that shows it.
@MainActor
final class EdgeCaseSweepTests: PracticeUITestCase {
  private func sweep(tag: String, dark: Bool = false, textSize: String? = nil) {
    let app = launch(["-UITestResetData", "-UITestEdgeCases", "-UITestTab", "game"], dark: dark, textSize: textSize)
    XCTAssertTrue(element(app, "game.resume").waitForExistence(timeout: 20), "the 200-hand night should be resumable")
    attach("edge-\(tag)-1-game-home")
    let opened = Date()
    element(app, "game.resume").tap()
    XCTAssertTrue(element(app, "score.menu").waitForExistence(timeout: 15), "scoreboard")
    XCTAssertLessThan(Date().timeIntervalSince(opened), 5, "opening a 200-hand night")
    attach("edge-\(tag)-2-scoreboard")
    app.swipeUp()
    attach("edge-\(tag)-3-scoreboard-scrolled")
    // Hand 200 must not wrap its number onto two lines ("#20" over "0").
    let number = app.staticTexts["#200"]
    if number.waitForExistence(timeout: 3) {
      XCTAssertLessThan(number.frame.height, 26, "the hand number wrapped")
    }
    // Summary of the night.
    element(app, "score.menu").tap()
    if element(app, "menu.summary").waitForExistence(timeout: 5) {
      element(app, "menu.summary").tap()
      XCTAssertTrue(element(app, "summary.done").waitForExistence(timeout: 10), "summary")
      attach("edge-\(tag)-4-summary")
      app.swipeUp()
      attach("edge-\(tag)-5-summary-scrolled")
      element(app, "summary.done").tap()
    }
    app.terminate()

    let cards = launch(["-UITestResetData", "-UITestEdgeCases", "-UITestTab", "cards"], dark: dark, textSize: textSize)
    XCTAssertTrue(cards.navigationBars["Cards"].waitForExistence(timeout: 20))
    attach("edge-\(tag)-6-cards")
    cards.terminate()

    let history = launch(["-UITestResetData", "-UITestEdgeCases", "-UITestTab", "game"], dark: dark, textSize: textSize)
    XCTAssertTrue(element(history, "game.history").waitForExistence(timeout: 20))
    element(history, "game.history").tap()
    XCTAssertTrue(element(history, "history.session").waitForExistence(timeout: 10))
    attach("edge-\(tag)-7-history")
    // The night whose card was deleted still opens.
    let rows = history.descendants(matching: .any).matching(identifier: "history.session")
    XCTAssertGreaterThanOrEqual(rows.count, 1)
    rows.element(boundBy: rows.count - 1).tap()
    Thread.sleep(forTimeInterval: 1.5)
    attach("edge-\(tag)-8-old-night")
    XCTAssertTrue(element(history, "log.row.1").waitForExistence(timeout: 10), "a night whose card was deleted must still open")
    attach("edge-\(tag)-8-old-night")
  }

  func testLight() { sweep(tag: "light") }
  func testDark() { sweep(tag: "dark", dark: true) }
  func testLargestText() { sweep(tag: "ax5", textSize: "UICTContentSizeCategoryAccessibilityXXXL") }
}
