import XCTest

/// The Practice tab: onboarding placement, playing a lesson (with a mistake that comes back), testing out
/// of a unit, with screenshots in light, dark and at accessibility text sizes.
@MainActor
final class PracticeTests: XCTestCase {
  private static let accessibilityM = "UICTContentSizeCategoryAccessibilityM"

  // MARK: Helpers

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func launch(
    _ flags: [String], dark: Bool = false, textSize: String? = nil, reduceMotion: Bool = false
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += flags
    if dark { app.launchArguments += ["-UITestDark"] }
    if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
    if reduceMotion { app.launchArguments += ["-UIAccessibilityReduceMotionEnabled", "YES"] }
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  @discardableResult
  private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
    let target = element(app, id)
    XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
    target.tap()
    return target
  }

  private func tapWhenHittable(_ app: XCUIApplication, _ id: String) {
    let target = element(app, id)
    var swipes = 0
    while !(target.exists && target.isHittable) && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing \(id)")
    target.tap()
  }

  private let practiceFlags = [
    "-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "new", "-UITestPracticeSeed", "5",
    "-UITestRevealAnswers", "-UITestToday", "2026-11-02",
  ]

  private func choice(_ app: XCUIApplication, correct: Bool) -> XCUIElement {
    let predicate = NSPredicate(
      format: "identifier BEGINSWITH 'lesson.choice.' AND value == %@", correct ? "correct" : "wrong")
    return app.buttons.matching(predicate).firstMatch
  }

  /// Answers the current multiple-choice question and taps through the feedback.
  private func answer(_ app: XCUIApplication, correct: Bool, shot: String? = nil) {
    let target = choice(app, correct: correct)
    XCTAssertTrue(target.waitForExistence(timeout: 10), "No \(correct ? "right" : "wrong") choice on screen")
    target.tap()
    let check = element(app, "lesson.check")
    if check.waitForExistence(timeout: 2) { check.tap() }
    let feedback = element(app, "lesson.feedback")
    XCTAssertTrue(feedback.waitForExistence(timeout: 10), "No feedback sheet")
    let title = element(app, "lesson.feedback.title").label
    if correct {
      XCTAssertNotEqual(title, "Not quite", "A right answer got the wrong feedback")
    } else {
      XCTAssertEqual(title, "Not quite")
    }
    if let shot { attach(shot) }
    tap(app, "lesson.continue")
  }

  // MARK: Onboarding

  func testNewPlayerLandsOnPracticeWithLessonOneNext() {
    let app = launch(["-UITestShowOnboarding"])
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "placement.new")
    attach("placement-new")
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.done"].tap()
    XCTAssertTrue(app.tabBars.buttons["Practice"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Practice"].isSelected, "A new player should land on Practice")
    let next = element(app, "path.node.u1l1")
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    XCTAssertEqual(next.value as? String, "Next")
    XCTAssertEqual(element(app, "path.node.u1l2").value as? String, "Locked")
    attach("practice-home-new-player")
  }

  func testRegularPlayerLandsOnGameWithSixUnitsTestedOut() {
    let app = launch(["-UITestShowOnboarding"])
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "placement.regular")
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.done"].tap()
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Game"].isSelected, "A regular player should land on Game")
    app.tabBars.buttons["Practice"].tap()
    XCTAssertEqual(element(app, "path.node.u1l1").value as? String, "Tested out")
    XCTAssertEqual(element(app, "path.node.u7l1").value as? String, "Next", "Unit 7 should be next")
    attach("practice-home-regular-player")
  }

  // MARK: A lesson

  private func lessonOne(dark: Bool = false, textSize: String? = nil, reduceMotion: Bool = false, tag: String) {
    let app = launch(practiceFlags, dark: dark, textSize: textSize, reduceMotion: reduceMotion)
    let node = element(app, "path.node.u1l1")
    XCTAssertTrue(node.waitForExistence(timeout: 10))
    attach("lesson1-\(tag)-0-path")
    node.tap()
    attach("lesson1-\(tag)-1-intro")
    tap(app, "lesson.start")
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10))
    attach("lesson1-\(tag)-2-question")

    // The first answer is wrong: the feedback says so, shows the right answer, and the question returns.
    answer(app, correct: false, shot: "lesson1-\(tag)-3-wrong")
    for n in 0..<7 {
      answer(app, correct: true, shot: n == 0 ? "lesson1-\(tag)-4-right" : nil)
    }
    XCTAssertTrue(element(app, "lesson.reask").waitForExistence(timeout: 10), "The mistake did not come back")
    attach("lesson1-\(tag)-5-reask")
    answer(app, correct: true)

    let stars = element(app, "complete.stars")
    XCTAssertTrue(stars.waitForExistence(timeout: 10), "No completion screen")
    XCTAssertEqual(stars.label, "2 of 3 stars", "One mistake should give two stars")
    XCTAssertTrue(element(app, "complete.xp").label.hasPrefix("+"))
    attach("lesson1-\(tag)-6-complete")
    tap(app, "lesson.continue")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    let next = element(app, "path.node.u1l2")
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    XCTAssertEqual(next.value as? String, "Next", "The next node should be unlocked")
    XCTAssertEqual(element(app, "path.node.u1l1").value as? String, "2 of 3 stars")
    attach("lesson1-\(tag)-7-path-after")
  }

  func testPlayLessonOneLight() { lessonOne(tag: "light") }
  func testPlayLessonOneDark() { lessonOne(dark: true, tag: "dark") }
  func testPlayLessonOneAccessibilitySize() { lessonOne(textSize: Self.accessibilityM, tag: "ax") }

  func testQuittingAskForConfirmation() {
    let app = launch(practiceFlags)
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    // Nothing answered yet: closing is immediate.
    tap(app, "lesson.close")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 5))
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")  // the intro is shown until the lesson has been finished once
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10))
    answer(app, correct: true)
    tap(app, "lesson.close")
    XCTAssertTrue(element(app, "lesson.quit.confirm").waitForExistence(timeout: 5), "No quit confirmation")
    attach("quit-confirmation")
    tap(app, "lesson.quit.confirm")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 5))
    XCTAssertEqual(element(app, "path.node.u1l1").value as? String, "Next", "A quit lesson must not count")
  }

  // MARK: Testing out

  func testTestingOutOfUnitOneUnlocksUnitTwo() {
    let app = launch(practiceFlags)
    tap(app, "path.testout.1")
    tap(app, "testout.start")
    for n in 0..<10 {
      if n == 0 { XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10)) }
      answer(app, correct: true)
    }
    let title = element(app, "complete.title")
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.label, "You tested out!")
    attach("testout-complete")
    tap(app, "lesson.continue")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    let next = element(app, "path.node.u2l1")
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    XCTAssertEqual(next.value as? String, "Next", "Unit 2 should be next after testing out of Unit 1")
    XCTAssertEqual(element(app, "path.node.u1l1").value as? String, "Tested out")
    attach("testout-path")
  }
}
