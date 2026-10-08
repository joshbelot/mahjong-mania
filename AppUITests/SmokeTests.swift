import XCTest

/// Launches the app, visits every tab and attaches a screenshot of each (light + dark).
@MainActor
final class SmokeTests: XCTestCase {
  private func launch(dark: Bool) -> XCUIApplication {
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

  private func visitTabs(dark: Bool) {
    let app = launch(dark: dark)
    let scheme = dark ? "dark" : "light"
    for tab in ["Game", "Helper", "Cards", "Learn"] {
      let button = app.tabBars.buttons[tab]
      XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing tab \(tab)")
      button.tap()
      XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 5), "Missing title \(tab)")
      attach("tab-\(tab.lowercased())-\(scheme)")
    }
    app.buttons["settings.open"].firstMatch.tap()
    XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
    attach("settings-\(scheme)")
    app.buttons["settings.done"].tap()
  }

  func testTabsLight() { visitTabs(dark: false) }
  func testTabsDark() { visitTabs(dark: true) }
}
