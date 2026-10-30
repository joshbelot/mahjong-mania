import XCTest

/// A look at the Phase 29 screens (intro with Sunny, feedback, hint, the three-star finish, the badge
/// celebration) in light, dark, the first accessibility size and with Reduce Motion.
@MainActor
final class PracticeLookTests: PracticeUITestCase {
  private func tour(tag: String, dark: Bool = false, textSize: String? = nil, reduceMotion: Bool = false) {
    let app = launch(practiceFlags, dark: dark, textSize: textSize, reduceMotion: reduceMotion)
    tap(app, "path.node.u1l1")
    attach("look-\(tag)-1-intro")
    tap(app, "lesson.start")
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10))
    answer(app, correct: false, shot: "look-\(tag)-3-wrong")
    tap(app, "lesson.hint.button")
    attach("look-\(tag)-2-hint")
    for n in 0..<8 { answer(app, correct: true, shot: n == 0 ? "look-\(tag)-4-right" : nil) }
    // The mistake comes back once.
    if element(app, "lesson.reask").waitForExistence(timeout: 3) { answer(app, correct: true) }
    XCTAssertTrue(element(app, "complete.title").waitForExistence(timeout: 10))
    Thread.sleep(forTimeInterval: reduceMotion ? 0.5 : 1.0)
    attach("look-\(tag)-5-complete")
    tap(app, "lesson.continue")
    if element(app, "celebration.continue").waitForExistence(timeout: 5) {
      attach("look-\(tag)-6-celebration")
    }
  }

  func testLight() { tour(tag: "light") }
  func testDark() { tour(tag: "dark", dark: true) }
  func testAccessibilitySize() { tour(tag: "ax", textSize: Self.accessibilityM) }
  func testReduceMotion() { tour(tag: "reduce", reduceMotion: true) }

  func testPerfectCompletion() {
    // All right first time except none: a clean run for the three-star banner.
    let app = launch(practiceFlags)
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    for _ in 0..<8 { answer(app, correct: true) }
    XCTAssertEqual(element(app, "complete.stars").label, "3 of 3 stars")
    XCTAssertEqual(element(app, "complete.title").label, "Perfect!")
    XCTAssertTrue(element(app, "complete.perfectcount").exists)
    XCTAssertEqual(element(app, "complete.perfectcount").label, "1 perfect lesson so far")
    Thread.sleep(forTimeInterval: 0.9)
    attach("look-perfect")
  }
}
