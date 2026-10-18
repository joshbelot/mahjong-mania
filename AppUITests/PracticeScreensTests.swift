import XCTest

/// A screenshot of every kind of question in light, dark and at an accessibility text size, opened directly
/// with `-UITestPlayNode`, plus the other Practice screens that no other test captures.
@MainActor
final class PracticeScreensTests: PracticeUITestCase {
  /// One lesson for each exercise type, and what the question looks like at a glance.
  private static let nodes: [(id: String, name: String)] = [
    ("u1l1", "name-tile"), ("u1l2", "find-tile"), ("u2l1", "group-name"), ("u2l2", "matches-line-colours"),
    ("u2l3", "matches-line-exposed"), ("u2l4", "which-hand"), ("u3l2", "joker-legal"), ("u4l1", "how-far"),
    ("u4l3", "needed-tile"), ("u5l1", "pick-hand-easy"), ("u5l3", "pick-hand-normal"), ("u7l3", "pick-hand-hard"),
    ("u6l1", "pass-one"), ("u6l2", "keep-or-pass"), ("u8l1", "pass-three-hint"), ("u8l2", "pass-three"),
    ("u9l1", "call-it"),
  ]

  private func tour(dark: Bool, textSize: String?, tag: String) {
    for (id, name) in Self.nodes {
      let app = launch(
        ["-UITestResetData", "-UITestTab", "practice", "-UITestPlayNode", id, "-UITestPracticeSeed", "7"],
        dark: dark, textSize: textSize)
      XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 15), "\(id) did not open")
      attach("screen-\(name)-\(tag)")
      app.terminate()
    }
  }

  func testEveryQuestionLight() { tour(dark: false, textSize: nil, tag: "light") }
  func testEveryQuestionDark() { tour(dark: true, textSize: nil, tag: "dark") }
  func testEveryQuestionAccessibilitySize() { tour(dark: false, textSize: Self.accessibilityM, tag: "ax") }

  /// The path with a node detail sheet, a played unit and a gold unit.
  func testPathStatesAndNodeSheets() {
    let app = launch(["-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "basics", "-UITestToday", "2026-11-02"])
    XCTAssertTrue(element(app, "path.node.u4l1").waitForExistence(timeout: 10))
    attach("path-basics-start")
    tap(app, "path.node.u1l1")
    XCTAssertTrue(element(app, "node.play").waitForExistence(timeout: 5), "No sheet for a tested-out node")
    attach("path-node-sheet-testedout")
  }

  func testSettingsPracticeSection() {
    let app = launch(["-UITestResetData", "-UITestTab", "practice"])
    tap(app, "settings.open")
    XCTAssertTrue(element(app, "settings.sound").waitForExistence(timeout: 5))
    attach("settings-1-top")
    app.swipeUp()
    app.swipeUp()
    XCTAssertTrue(element(app, "settings.practice.goal").waitForExistence(timeout: 5))
    attach("settings-2-practice")
  }
}
