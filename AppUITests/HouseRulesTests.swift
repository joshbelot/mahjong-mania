import XCTest

/// The rule book (SPEC §17.4): reading a rule, changing its choice and watching the live example
/// follow, locked rules, and a custom scoring rule that shows up in Record hand. Light, dark and the
/// largest text size, with screenshots.
@MainActor
final class HouseRulesTests: XCTestCase {
  private let players = ["Alex", "Bea", "Cy", "Dee"]

  private func launch(dark: Bool = false, largeText: Bool = false) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData"]
    if dark { app.launchArguments += ["-UITestDark"] }
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
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
    var swipes = 0
    // Lists create rows lazily, so scroll until the row exists.
    while !element.waitForExistence(timeout: 2) && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(element.exists, "Missing \(id)")
    swipes = 0
    while !element.isHittable && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
    swipes = 0
    while !element.isHittable && swipes < 10 {
      app.swipeDown()
      swipes += 1
    }
    XCTAssertTrue(element.isHittable, "\(id) is not tappable")
    element.tap()
  }

  private func openHouseRules(_ app: XCUIApplication) {
    tapID(app, "settings.open")
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Settings did not open")
    tapID(app, "settings.houseRules")
    XCTAssertTrue(el(app, "rule.row.pay.jokerless").waitForExistence(timeout: 10), "Missing the rule book")
  }

  // MARK: Reading and changing a rule

  private func jokerlessToTriple(dark: Bool) {
    let app = launch(dark: dark)
    openHouseRules(app)
    attach("rules-book-\(dark ? "dark" : "light")")

    tapID(app, "rule.row.pay.jokerless")
    let example = el(app, "rule.example")
    XCTAssertTrue(example.waitForExistence(timeout: 10), "Missing the example")
    XCTAssertTrue(
      example.label.contains("Cy pays 100, Dee and Al pay 50 each. Bea collects 200."), "Got '\(example.label)'")
    attach("rules-jokerless-double-\(dark ? "dark" : "light")")

    tapID(app, "rule.choice.3")
    let changed = NSPredicate(format: "label CONTAINS %@", "Cy pays 150, Dee and Al pay 75 each. Bea collects 300.")
    expectation(for: changed, evaluatedWith: el(app, "rule.example"))
    waitForExpectations(timeout: 10)
    XCTAssertTrue(el(app, "rule.title").label.contains("triple"), "The title should follow the choice")
    attach("rules-jokerless-triple-\(dark ? "dark" : "light")")
  }

  func testChangingJokerlessToTripleUpdatesTheExampleLight() { jokerlessToTriple(dark: false) }
  func testChangingJokerlessToTripleUpdatesTheExampleDark() { jokerlessToTriple(dark: true) }

  func testLockedRuleSaysWhyItCannotBeSwitchedOff() {
    let app = launch()
    openHouseRules(app)
    tapID(app, "rule.row.concealed")
    XCTAssertTrue(el(app, "rule.meaning").waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.staticTexts["This is part of how the game is played, so it can't be switched off."].exists)
    attach("rules-locked-light")
  }

  func testRuleBookAtTheLargestTextSize() {
    let app = launch(dark: true, largeText: true)
    openHouseRules(app)
    attach("rules-book-ax5-dark")
    tapID(app, "rule.row.pay.jokerless")
    XCTAssertTrue(el(app, "rule.example").waitForExistence(timeout: 10))
    attach("rules-jokerless-ax5-dark")
  }

  // MARK: A custom scoring rule, applied

  func testACustomScoringRuleIsAppliedInRecordHand() {
    let app = launch()
    openHouseRules(app)
    tapID(app, "rules.add")
    tapID(app, "ruleEditor.pays.triple")
    let example = el(app, "ruleEditor.example")
    XCTAssertTrue(example.waitForExistence(timeout: 10))
    XCTAssertTrue(example.label.contains("Cy pays 150, Dee and Al pay 75 each"), "Triple on top: \(example.label)")
    attach("rules-add-light")
    tapID(app, "ruleEditor.save")
    XCTAssertTrue(
      el(app, "rule.row.pay.jokerless").waitForExistence(timeout: 10), "Back on the rule book after saving")
    attach("rules-ours-light")

    // Out of Settings, start a game night (it copies the default rule book) and record a hand.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    tapID(app, "settings.done")
    tapID(app, "game.start")
    tapID(app, "setup.addPlayerToggle")
    for name in players {
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
    tapID(app, "score.record")
    tapID(app, "record.winner.Alex")
    tapID(app, "record.how.discard")
    tapID(app, "record.thrower.Bea")
    tapID(app, "record.points.25")
    let explanation = el(app, "record.explanation")
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.label.contains("On every win: everyone pays triple"),
      "The explanation should name the rule, got '\(explanation.label)'")
    attach("rules-record-light")
    tapID(app, "record.save")
    // Thrower 25 x2 x3 = 150, the other two 25 x1 x3 = 75 each: Alex collects 300.
    XCTAssertTrue(el(app, "record.save").waitForNonExistence(timeout: 10), "The record sheet did not close")
    let score = el(app, "score.Alex")
    if !score.waitForExistence(timeout: 3) { app.swipeDown() }
    XCTAssertTrue(score.waitForExistence(timeout: 10), "Missing Alex's score")
    let deadline = Date().addingTimeInterval(15)
    while Date() < deadline && !score.label.contains("300") { Thread.sleep(forTimeInterval: 0.25) }
    XCTAssertTrue(score.label.contains("300"), "Alex's score label is '\(score.label)'")
  }
}
