import XCTest

/// The 1.2 simulator QA pass (SPEC §18.12, Phase 27): a beginner on a fresh install plays through Unit 2,
/// and an experienced player tests out of three units at once.
@MainActor
final class PracticeQATests: PracticeUITestCase {
  private let flags = [
    "-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "new", "-UITestRevealAnswers",
    "-UITestToday", "2026-11-02", "-UITestDailyGoal", "regular",
  ]

  /// Plays the lesson behind `path.node.<id>`: every answer right except `mistakes` first answers, with one
  /// hint used on the first question when `useHint` is set.
  private func play(_ app: XCUIApplication, node: String, mistakes: Int = 0, useHint: Bool = false, shot: String? = nil) {
    tap(app, "path.node.\(node)")
    if element(app, "lesson.start").waitForExistence(timeout: 3) { tap(app, "lesson.start") }
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10), "\(node) did not open")
    var asked = 0
    var madeMistakes = 0
    while !element(app, "complete.title").exists {
      if asked == 0, useHint, element(app, "lesson.hint.button").isEnabled {
        tap(app, "lesson.hint.button")
        Thread.sleep(forTimeInterval: 0.3)
      }
      let wrong = madeMistakes < mistakes && asked % 3 == 1
      let target = choice(app, correct: !wrong)
      guard target.waitForExistence(timeout: 10) else {
        if element(app, "complete.title").waitForExistence(timeout: 2) { break }
        XCTFail("\(node): no answer button on question \(asked + 1)")
        return
      }
      if wrong { madeMistakes += 1 }
      target.tap()
      let check = element(app, "lesson.check")
      if check.waitForExistence(timeout: 1) { check.tap() }
      XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10), "\(node): no feedback on question \(asked + 1)")
      if asked == 2, let shot { attach("\(shot)-feedback") }
      tap(app, "lesson.continue")
      asked += 1
      XCTAssertLessThan(asked, 25, "\(node) never finished")
    }
    XCTAssertTrue(element(app, "complete.title").waitForExistence(timeout: 10), "\(node): no completion screen")
    if let shot { attach("\(shot)-complete") }
    tap(app, "lesson.continue")
    // Celebrations (level, badges, goal) until the path is back.
    while element(app, "celebration.continue").waitForExistence(timeout: 2) || element(app, "goal.regular").exists {
      if element(app, "goal.regular").exists { tap(app, "goal.regular") } else { tap(app, "celebration.continue") }
    }
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10), "\(node): did not return to the path")
  }

  func testBeginnerPlaysThroughUnitTwo() {
    let app = launch(flags)
    for lesson in 1...3 {
      play(app, node: "u1l\(lesson)", mistakes: lesson == 2 ? 2 : 0, useHint: lesson == 3, shot: "qa-u1l\(lesson)")
    }
    // The checkpoint unlocks Unit 2.
    play(app, node: "u1c", shot: "qa-u1c")
    XCTAssertEqual(element(app, "path.node.u2l1").value as? String, "Next", "Unit 2 did not open")
    for lesson in 1...4 {
      play(app, node: "u2l\(lesson)", mistakes: lesson == 3 ? 1 : 0, shot: "qa-u2l\(lesson)")
    }
    play(app, node: "u2c", shot: "qa-u2c")
    XCTAssertEqual(element(app, "path.node.u3l1").value as? String, "Next", "Unit 3 did not open")
    XCTAssertEqual(element(app, "path.node.u1l2").value as? String, "2 of 3 stars", "A lesson with 2 mistakes keeps ★★")
    attach("qa-path-after-unit-2")
    // The profile shows the progress.
    tap(app, "header.level")
    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    attach("qa-profile")
  }

  func testExperiencedPlayerTestsOutOfThreeUnits() {
    let app = launch(flags)
    tap(app, "path.testout.3")
    tap(app, "testout.start")
    var asked = 0
    while !element(app, "complete.title").exists && asked < 12 {
      let target = choice(app, correct: true)
      guard target.waitForExistence(timeout: 10) else { break }
      target.tap()
      if element(app, "lesson.check").waitForExistence(timeout: 1) { element(app, "lesson.check").tap() }
      XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10))
      tap(app, "lesson.continue")
      asked += 1
    }
    XCTAssertEqual(element(app, "complete.title").label, "You tested out!")
    attach("qa-testout-unit-3")
    tap(app, "lesson.continue")
    while element(app, "celebration.continue").waitForExistence(timeout: 2) || element(app, "goal.regular").exists {
      if element(app, "goal.regular").exists { tap(app, "goal.regular") } else { tap(app, "celebration.continue") }
    }
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    XCTAssertEqual(element(app, "path.node.u4l1").value as? String, "Next", "Unit 4 should be next")
    for node in ["u1l1", "u2l3", "u3l1"] {
      XCTAssertEqual(element(app, "path.node.\(node)").value as? String, "Tested out", node)
    }
    attach("qa-testout-path")
  }
}
