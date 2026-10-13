import XCTest

/// Runs key screens at the largest accessibility text size and checks that custom layouts stack
/// instead of truncating or breaking words. Screenshots are attached for both colour schemes.
@MainActor
final class LargeTextTests: XCTestCase {
  private func launch(dark: Bool) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += [
      "-UITestResetData",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
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

  private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func tapID(_ app: XCUIApplication, _ id: String) {
    let element = el(app, id)
    XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(id)")
    element.tap()
  }

  /// Swipes up until a (lazily created) element exists; the list is far taller than the screen.
  private func scrollTo(_ app: XCUIApplication, _ id: String) {
    var swipes = 0
    while !el(app, id).exists && swipes < 8 {
      app.swipeUp()
      swipes += 1
    }
  }

  private func check(dark: Bool) {
    let app = launch(dark: dark)
    let scheme = dark ? "dark" : "light"

    // Cards: New and Import stack instead of squeezing side by side.
    app.tabBars.buttons["Cards"].tap()
    let new = el(app, "cards.new")
    let importButton = el(app, "cards.import")
    XCTAssertTrue(importButton.waitForExistence(timeout: 10))
    XCTAssertGreaterThanOrEqual(
      importButton.frame.minY, new.frame.maxY, "New and Import should be stacked at accessibility sizes")
    attach("large-cards-\(scheme)")

    // Game: after one hand the scoreboard shows full names and unwrapped scores.
    app.tabBars.buttons["Game"].tap()
    tapID(app, "game.start")
    tapID(app, "setup.addPlayerToggle")
    for name in ["Alex", "Bea", "Cy", "Dee"] {
      let field = el(app, "setup.newName")
      XCTAssertTrue(field.waitForExistence(timeout: 10))
      field.tap()
      let tip = app.buttons["Continue"]
      if tip.waitForExistence(timeout: 1) { tip.tap() }
      field.typeText(name)
      tapID(app, "setup.addPlayer")
      XCTAssertTrue(el(app, "setup.player.\(name)").waitForExistence(timeout: 5))
    }
    tapID(app, "setup.start")
    XCTAssertTrue(el(app, "score.Alex").waitForExistence(timeout: 10))
    scrollTo(app, "score.record")
    tapID(app, "score.record")
    tapID(app, "record.winner.Bea")
    tapID(app, "record.how.discard")
    scrollTo(app, "record.thrower.Cy")
    tapID(app, "record.thrower.Cy")
    scrollTo(app, "record.points.30")
    tapID(app, "record.points.30")
    attach("large-record-\(scheme)")
    scrollTo(app, "record.save")
    tapID(app, "record.save")
    XCTAssertTrue(el(app, "record.save").waitForNonExistence(timeout: 10))

    var swipes = 0
    while !el(app, "score.Bea").exists && swipes < 8 {
      app.swipeDown()
      swipes += 1
    }
    let score = el(app, "score.Bea")
    XCTAssertTrue(score.waitForExistence(timeout: 10))
    XCTAssertEqual(score.label, "plus 120 points")
    XCTAssertGreaterThan(
      score.frame.width, score.frame.height, "A score must stay on one line (no \"+12\" / \"0\" wrap)")
    attach("large-scoreboard-\(scheme)")
  }

  func testLargeTextLight() { check(dark: false) }
  func testLargeTextDark() { check(dark: true) }
}
