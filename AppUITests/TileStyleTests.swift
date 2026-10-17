import XCTest

/// Settings → Tile style: picks each of the four styles, screenshots the preview and the Helper rack
/// in light and dark.
@MainActor
final class TileStyleTests: XCTestCase {
  private let styles = ["classic", "traditional", "largePrint", "modern"]
  private static let rack = "1C,5C,9C,5B,7B,9B,3D,6D,8D,N,E,R,0"

  private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func tap(_ app: XCUIApplication, _ id: String) {
    let element = el(app, id)
    var swipes = 0
    while !element.waitForExistence(timeout: 2) && swipes < 8 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(element.exists, "Missing \(id)")
    swipes = 0
    while !element.isHittable && swipes < 8 {
      app.swipeUp()
      swipes += 1
    }
    element.tap()
  }

  private func run(dark: Bool) {
    continueAfterFailure = false
    let scheme = dark ? "dark" : "light"
    let app = XCUIApplication()
    app.launchArguments += [
      "-UITestResetData", "-UITestTab", "helper", "-UITestAssist", "peek", "-UITestHelperRack", Self.rack,
    ]
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()
    XCTAssertTrue(app.navigationBars["Helper"].waitForExistence(timeout: 10))

    tap(app, "settings.open")
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    tap(app, "settings.tileStyle")
    for style in styles {
      tap(app, "tileStyle.option.\(style)")
      XCTAssertTrue(el(app, "tileStyle.option.\(style)").isSelected, "\(style) should be selected")
      attach("tile-style-\(style)-preview-\(scheme)")
    }
    // Back to Settings, close it, and look at the rack in the last chosen style, then each of the others.
    for style in styles {
      app.navigationBars.buttons.element(boundBy: 0).tap()
      app.buttons["settings.done"].tap()
      XCTAssertTrue(el(app, "rack.count").waitForExistence(timeout: 10))
      attach("tile-style-\(style == styles.last ? "modern" : style)-helper-\(scheme)")
      if style == styles.last { break }
      tap(app, "settings.open")
      tap(app, "settings.tileStyle")
      tap(app, "tileStyle.option.\(styles[styles.firstIndex(of: style)! + 1])")
    }
  }

  func testEveryStyleLight() { run(dark: false) }
  func testEveryStyleDark() { run(dark: true) }

  func testTheChoiceSurvivesARelaunch() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData", "-UITestTileStyle", "modern"]
    app.launch()
    tap(app, "settings.open")
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    let row = el(app, "settings.tileStyle")
    var swipes = 0
    while !row.waitForExistence(timeout: 2) && swipes < 8 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(row.label.contains("Modern"), "Settings should show the chosen style, got '\(row.label)'")
  }
}
