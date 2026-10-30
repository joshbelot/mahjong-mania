import XCTest

/// Produces the App Store screenshots (SPEC §19.7). Demo data, a fixed clock, light mode, and only the
/// built-in Practice Card. Run on the iPhone 17 Pro Max simulator (1320 x 2868) with the status bar set by
/// `tools/app_store_screenshots.sh`; the PNGs go to `$SCREENSHOT_DIR` (a `TEST_RUNNER_SCREENSHOT_DIR` variable).
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
  private let outputDirectory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]

  private func launch(_ tab: String, _ extra: [String] = []) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += [
      "-UITestResetData", "-UITestDemoData", "-UITestTab", tab, "-UITestToday", "2026-10-30", "-UITestHour", "12",
      "-UITestPracticeSeed", "5", "-UITestRevealAnswers", "-UITestDayLog", "2026-10-25,2026-10-26,2026-10-27,2026-10-28,2026-10-29",
    ] + extra
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

  private func shot(_ name: String) {
    Thread.sleep(forTimeInterval: 0.8)
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
    if let outputDirectory {
      try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
      try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(name).png"))
    }
  }

  func testPracticePathLessonAndPerfectFinish() {
    let app = launch("practice")
    XCTAssertTrue(element(app, "path.node.u2l2").waitForExistence(timeout: 20))
    Thread.sleep(forTimeInterval: 1)
    app.swipeDown()
    app.swipeDown()
    Thread.sleep(forTimeInterval: 0.6)
    shot("01-practice-path")
    while !element(app, "path.node.u2l2").isHittable { app.swipeUp() }
    element(app, "path.node.u2l2").tap()
    XCTAssertTrue(element(app, "lesson.start").waitForExistence(timeout: 5))
    element(app, "lesson.start").tap()
    // First question: right, so the feedback shows Sunny cheering.
    for question in 0..<8 {
      let right = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'lesson.choice.'")).allElementsBoundByIndex
      XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10), "question \(question)")
      _ = right
      let correct = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'lesson.choice.' AND value == 'correct'")).firstMatch
      XCTAssertTrue(correct.waitForExistence(timeout: 10), "a right choice for question \(question)")
      correct.tap()
      XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10))
      if question == 0 { shot("02-lesson-feedback") }
      element(app, "lesson.continue").tap()
    }
    XCTAssertTrue(element(app, "complete.title").waitForExistence(timeout: 10))
    Thread.sleep(forTimeInterval: 1.2)
    shot("03-three-stars")
  }

  func testHelperWithSuggestions() {
    let app = launch(
      "helper",
      ["-UITestHelperRack", "1C,3C,6C,2B,5B,5B,8B,3D,5D,9D,N,E,J", "-UITestHelperMode", "playing", "-UITestAssist", "peek"])
    XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20))
    let reveal = element(app, "helper.results.reveal")
    XCTAssertTrue(reveal.waitForExistence(timeout: 10))
    reveal.tap()
    Thread.sleep(forTimeInterval: 1.0)
    // Fold the tile picker away so the closest hands have the screen.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.64)).tap()
    Thread.sleep(forTimeInterval: 1.0)
    shot("04-helper")
  }

  func testGameNightScoreboardAndSettleUp() {
    let app = launch("game")
    XCTAssertTrue(element(app, "game.resume").waitForExistence(timeout: 20))
    element(app, "game.resume").tap()
    XCTAssertTrue(element(app, "score.Alex").waitForExistence(timeout: 10))
    shot("05-scoreboard")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(element(app, "game.history").waitForExistence(timeout: 10))
    element(app, "game.history").tap()
    XCTAssertTrue(element(app, "history.session").waitForExistence(timeout: 10))
    element(app, "history.session").tap()
    XCTAssertTrue(element(app, "score.menu").waitForExistence(timeout: 10))
    element(app, "score.menu").tap()
    XCTAssertTrue(element(app, "menu.summary").waitForExistence(timeout: 5))
    element(app, "menu.summary").tap()
    XCTAssertTrue(element(app, "settle.line.0").waitForExistence(timeout: 10) || element(app, "settle.none").exists)
    app.swipeUp()
    shot("06-settle-up")
  }

  func testCardsWithPatternAndHouseRules() {
    let app = launch("cards")
    XCTAssertTrue(element(app, "cards.row.practice-v1").waitForExistence(timeout: 20))
    element(app, "cards.row.practice-v1").tap()
    XCTAssertTrue(element(app, "line.row.0").waitForExistence(timeout: 10))
    shot("07-cards")
    app.terminate()

    let rules = launch("game")
    XCTAssertTrue(rules.buttons["settings.open"].firstMatch.waitForExistence(timeout: 20))
    rules.buttons["settings.open"].firstMatch.tap()
    XCTAssertTrue(element(rules, "settings.houseRules").waitForExistence(timeout: 10))
    element(rules, "settings.houseRules").tap()
    Thread.sleep(forTimeInterval: 1)
    shot("08-house-rules")
  }
}
