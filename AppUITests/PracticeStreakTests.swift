import XCTest

/// Daily goal, streak flame, freezes, milestones, the break message and the profile, using injected day logs
/// (`-UITestDayLog`) and a fixed date (`-UITestToday 2026-11-02`).
@MainActor
final class PracticeStreakTests: PracticeUITestCase {
  private func flags(days: [String] = [], today: String = "2026-11-02", goal: String? = "casual", extra: [String] = []) -> [String] {
    var result = [
      "-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "new", "-UITestPracticeSeed", "5",
      "-UITestRevealAnswers", "-UITestToday", today,
    ]
    if let goal { result += ["-UITestDailyGoal", goal] }
    if !days.isEmpty { result += ["-UITestDayLog", days.joined(separator: ",")] }
    return result + extra
  }

  private func streakValue(_ app: XCUIApplication) -> String {
    let streak = element(app, "header.streak")
    XCTAssertTrue(streak.waitForExistence(timeout: 10), "No streak flame")
    return streak.value as? String ?? ""
  }

  func testFlameShowsTheInjectedStreak() {
    let app = launch(flags(days: ["2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"]))
    XCTAssertEqual(streakValue(app), "4 days")
    attach("streak-flame-4")
  }

  func testAFreezeKeepsTheStreakAndSaysSo() {
    // Seven days earn a freeze; October 31 is missed; it is now November 1.
    let days = (24...30).map { "2026-10-\($0)" }
    let app = launch(flags(days: days, today: "2026-11-01"))
    let banner = element(app, "banner.freeze")
    XCTAssertTrue(banner.waitForExistence(timeout: 10), "No freeze message")
    XCTAssertTrue(app.staticTexts["Your streak freeze kept your 7-day streak safe."].exists)
    XCTAssertEqual(streakValue(app), "7 days")
    attach("streak-freeze-used-light")
    tap(app, "banner.freeze.dismiss")
    XCTAssertFalse(element(app, "banner.freeze").waitForExistence(timeout: 1))
  }

  func testABrokenStreakRestartsKindly() {
    let app = launch(flags(days: ["2026-10-20", "2026-10-21", "2026-10-22"], today: "2026-11-02"))
    let banner = element(app, "banner.broken")
    XCTAssertTrue(banner.waitForExistence(timeout: 10), "No restart message")
    XCTAssertTrue(app.staticTexts["New streak, same skills. You've played 3 days in total."].exists)
    XCTAssertEqual(streakValue(app), "0 days")
    attach("streak-broken-light")
  }

  func testPlayingOnTheThirdDayShowsTheMilestone() {
    let app = launch(flags(days: ["2026-10-31", "2026-11-01"], today: "2026-11-02"))
    XCTAssertEqual(streakValue(app), "2 days")
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    for _ in 0..<8 { answer(app, correct: true) }
    tap(app, "lesson.continue")
    // Level 2, First Steps, then the 3-day milestone instead of the plain goal screen.
    var sawMilestone = false
    for _ in 0..<4 {
      guard element(app, "celebration.continue").waitForExistence(timeout: 5) else { break }
      if element(app, "celebration.milestone.3").exists {
        sawMilestone = true
        XCTAssertEqual(element(app, "celebration.title").label, "3-day streak!")
        attach("streak-milestone-3")
      }
      tap(app, "celebration.continue")
    }
    XCTAssertTrue(sawMilestone, "No milestone screen")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    XCTAssertEqual(streakValue(app), "3 days")
  }

  func testTheGoalIsAskedOnceAfterTheFirstLesson() {
    let app = launch(flags(goal: nil))
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    for _ in 0..<8 { answer(app, correct: true) }
    tap(app, "lesson.continue")
    // Level, badge, then the goal choice (which also says today's goal is done).
    for _ in 0..<2 {
      XCTAssertTrue(element(app, "celebration.continue").waitForExistence(timeout: 5))
      tap(app, "celebration.continue")
    }
    XCTAssertTrue(element(app, "goal.regular").waitForExistence(timeout: 5), "The daily goal choice is missing")
    attach("goal-choice")
    tap(app, "goal.regular")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    // Today already counted under the first goal; the new one applies from tomorrow.
    XCTAssertEqual(element(app, "header.goal").value as? String, "Done for today")
    // A second lesson does not ask again, and the goal is not celebrated twice.
    tap(app, "path.node.u1l2")
    tap(app, "lesson.start")
    for _ in 0..<8 { answer(app, correct: true) }
    tap(app, "lesson.continue")
    XCTAssertFalse(element(app, "goal.casual").waitForExistence(timeout: 2))
    var goalScreens = 0
    while element(app, "celebration.continue").waitForExistence(timeout: 3) {
      if element(app, "celebration.goal").exists { goalScreens += 1 }
      tap(app, "celebration.continue")
    }
    XCTAssertEqual(goalScreens, 0, "Today's goal was already celebrated")
  }

  private func openProfile(_ app: XCUIApplication) {
    for _ in 0..<3 {
      app.swipeDown()
      let level = element(app, "header.level")
      XCTAssertTrue(level.waitForExistence(timeout: 10), "No header")
      level.tap()
      if app.navigationBars["Profile"].waitForExistence(timeout: 4) { return }
    }
    XCTFail("The profile did not open")
  }

  private func profileTour(dark: Bool, textSize: String?, tag: String) {
    let days = (10...30).filter { $0 % 4 != 0 }.map { "2026-10-\($0)" }
    let app = launch(flags(days: days + ["2026-10-31", "2026-11-01"], today: "2026-11-02", goal: "regular"), dark: dark, textSize: textSize)
    XCTAssertTrue(element(app, "header.level").waitForExistence(timeout: 10), "No header")
    attach("profile-\(tag)-0-home")
    openProfile(app)
    XCTAssertEqual(element(app, "profile.streak.current").value as? String, "4")
    XCTAssertEqual(element(app, "profile.goal").label, "Regular: 2 lessons")
    attach("profile-\(tag)-1")
    app.swipeUp()
    attach("profile-\(tag)-2")
    app.swipeUp()
    attach("profile-\(tag)-3")
    app.swipeUp()
    attach("profile-\(tag)-4")
  }

  func testProfileLight() { profileTour(dark: false, textSize: nil, tag: "light") }
  func testProfileDark() { profileTour(dark: true, textSize: nil, tag: "dark") }
  func testProfileAccessibilitySize() { profileTour(dark: false, textSize: Self.accessibilityM, tag: "ax") }
}
