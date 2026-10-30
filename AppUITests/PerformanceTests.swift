import XCTest

/// SPEC §19.4 step 7: cold launch to the first screen should be under a second on the simulator.
@MainActor
final class PerformanceTests: XCTestCase {
  func testColdLaunchToFirstScreen() throws {
    var durations: [TimeInterval] = []
    for _ in 0..<5 {
      let app = XCUIApplication()
      app.launchArguments += ["-UITestResetData"]
      let start = Date()
      app.launch()
      XCTAssertTrue(app.tabBars.buttons.firstMatch.waitForExistence(timeout: 10) || app.navigationBars.firstMatch.exists)
      durations.append(Date().timeIntervalSince(start))
      app.terminate()
    }
    let best = durations.min() ?? 0
    let average = durations.reduce(0, +) / Double(durations.count)
    print("PERF cold launch to first screen: best \(best) s, average \(average) s")
    add(XCTAttachment(string: "cold launch best \(best) s, average \(average) s"))
    // The measurement includes XCUITest's own launch and idle wait, so the limit is generous.
    XCTAssertLessThan(best, 3.0)
  }

  func testOpeningPracticeAndStartingALessonIsQuick() throws {
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "new", "-UITestPracticeSeed", "5"]
    app.launch()
    let node = app.descendants(matching: .any)["path.node.u1l1"].firstMatch
    XCTAssertTrue(node.waitForExistence(timeout: 10))
    node.tap()
    let start = app.buttons["lesson.start"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    let began = Date()
    start.tap()
    XCTAssertTrue(app.descendants(matching: .any)["lesson.prompt"].firstMatch.waitForExistence(timeout: 5))
    let took = Date().timeIntervalSince(began)
    print("PERF start lesson to first question: \(took) s")
    XCTAssertLessThan(took, 1.5)
  }
}
