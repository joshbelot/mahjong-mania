import XCTest

/// Shared helpers for the Practice UI tests.
@MainActor
class PracticeUITestCase: XCTestCase {
  static let accessibilityM = "UICTContentSizeCategoryAccessibilityM"

  func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func launch(
    _ flags: [String], dark: Bool = false, textSize: String? = nil, reduceMotion: Bool = false
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += flags
    if dark { app.launchArguments += ["-UITestDark"] }
    if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
    if reduceMotion { app.launchArguments += ["-UITestReduceMotion"] }
    app.launch()
    return app
  }

  func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  @discardableResult
  func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
    let target = element(app, id)
    XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
    target.tap()
    return target
  }

  func tapWhenHittable(_ app: XCUIApplication, _ id: String) {
    let target = element(app, id)
    var swipes = 0
    while !(target.exists && target.isHittable) && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing \(id)")
    target.tap()
  }

  let practiceFlags = [
    "-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "new", "-UITestPracticeSeed", "5",
    "-UITestRevealAnswers", "-UITestToday", "2026-11-02",
  ]

  func choice(_ app: XCUIApplication, correct: Bool) -> XCUIElement {
    let predicate = NSPredicate(
      format: "identifier BEGINSWITH 'lesson.choice.' AND value == %@", correct ? "correct" : "wrong")
    return app.buttons.matching(predicate).firstMatch
  }

  /// Answers the current multiple-choice question and taps through the feedback.
  func answer(_ app: XCUIApplication, correct: Bool, shot: String? = nil) {
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

}
