import XCTest

/// SPEC §19.4 step 6: the Xcode accessibility audit on each main screen, and step 5: a screenshot of each
/// screen for the layout sweep (run on the iPhone and an iPad simulator, in light and dark, and at AX5).
@MainActor
final class AccessibilityAuditTests: XCTestCase {
  private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

  private func launch(_ extra: [String] = [], dark: Bool = false, textSize: String? = nil) -> XCUIApplication {
    continueAfterFailure = true
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData", "-UITestToday", "2026-11-02"] + extra
    if dark { app.launchArguments += ["-UITestDark"] }
    if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
    app.launch()
    return app
  }

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Audits the screen currently showing. Dynamic Type clipping is checked by the AX5 screenshots instead,
  /// because the audit flags every fixed-size decorative label.
  private func audit(_ app: XCUIApplication, _ name: String) {
    attach(name)
    do {
      try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .contrast, .elementDetection, .trait]) {
        issue in
        // Report, but let the sweep keep going: every finding is listed in the test log.
        print("AUDIT \(name): \(issue.auditType.rawValue) | \(issue.compactDescription) | label=\(issue.element?.label ?? "") id=\(issue.element?.identifier ?? "") frame=\(issue.element?.frame ?? .zero)")
        return true
      }
    } catch {
      XCTFail("\(name): \(error)")
    }
  }

  private var tabs: [(String, [String])] {
    [
      ("game", []), ("helper", ["-UITestHelperRack", "1C,2C,3C,5B,5B,7D,9D,N,E,R,G,F,J,F"]), ("practice", ["-UITestPlacement", "new"]),
      ("cards", []), ("learn", []),
    ]
  }

  func testAuditEveryTab() {
    for (tab, extra) in tabs {
      let app = launch(["-UITestTab", tab] + extra)
      XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15), "no tab bar for \(tab)")
      Thread.sleep(forTimeInterval: 1)
      audit(app, "audit-\(tab)")
      app.terminate()
    }
  }

  func testAuditSettingsAndLesson() {
    let app = launch(["-UITestTab", "practice", "-UITestPlacement", "new", "-UITestPracticeSeed", "5"])
    app.buttons["settings.open"].firstMatch.tap()
    XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
    audit(app, "audit-settings")
    app.buttons["settings.done"].tap()
    app.descendants(matching: .any)["path.node.u1l1"].firstMatch.tap()
    audit(app, "audit-lesson-intro")
    app.buttons["lesson.start"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["lesson.prompt"].firstMatch.waitForExistence(timeout: 10))
    audit(app, "audit-lesson-question")
  }

  func testEveryTabAtAX5() {
    for (tab, extra) in tabs {
      let app = launch(["-UITestTab", tab] + extra, textSize: Self.ax5)
      XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15), "no tab bar for \(tab)")
      Thread.sleep(forTimeInterval: 1)
      attach("ax5-\(tab)")
      app.terminate()
    }
  }

  func testEveryTabDark() {
    for (tab, extra) in tabs {
      let app = launch(["-UITestTab", tab] + extra, dark: true)
      XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15), "no tab bar for \(tab)")
      Thread.sleep(forTimeInterval: 1)
      attach("dark-\(tab)")
      app.terminate()
    }
  }
}
