import XCTest

@MainActor
final class SettingsTests: XCTestCase {
  private func launch(dark: Bool = false) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData"]
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()
    return app
  }

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
    var swipes = 0
    while !(element.exists && element.isHittable) && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
  }

  func testAssistLevelCanBeChangedAndScreenshots() {
    let app = launch()
    app.buttons["settings.open"].firstMatch.tap()
    let picker = app.segmentedControls["settings.assist"]
    XCTAssertTrue(picker.waitForExistence(timeout: 10), "Missing assist picker")
    picker.buttons["Coach"].tap()
    XCTAssertTrue(picker.buttons["Coach"].isSelected, "Coach was not selected")
    attach("settings-top-light")
    let reset = app.buttons["settings.reset"]
    scrollTo(reset, in: app)
    attach("settings-bottom-light")
  }

  func testResetAllDataReturnsToOnboarding() {
    let app = launch(dark: true)
    app.buttons["settings.open"].firstMatch.tap()
    let reset = app.buttons["settings.reset"]
    scrollTo(reset, in: app)
    XCTAssertTrue(reset.exists, "Reset button not found")
    reset.tap()
    let first = app.buttons["Continue…"]
    XCTAssertTrue(first.waitForExistence(timeout: 5), "First confirmation did not appear")
    attach("settings-reset-confirm-1-dark")
    first.tap()
    let second = app.alerts.buttons["Delete everything"]
    XCTAssertTrue(second.waitForExistence(timeout: 5), "Second confirmation did not appear")
    attach("settings-reset-confirm-2-dark")
    second.tap()
    XCTAssertTrue(
      app.buttons["onboarding.next"].waitForExistence(timeout: 10), "Onboarding did not return")
    attach("settings-after-reset-dark")
  }

  func testCancelKeepsData() {
    let app = launch()
    app.buttons["settings.open"].firstMatch.tap()
    let reset = app.buttons["settings.reset"]
    scrollTo(reset, in: app)
    reset.tap()
    let first = app.buttons["Continue…"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    first.tap()
    let alert = app.alerts.buttons["Cancel"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5), "Second confirmation did not appear")
    alert.tap()
    XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
    app.buttons["settings.done"].tap()
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 5), "Settings closed but app state lost")
  }
}
