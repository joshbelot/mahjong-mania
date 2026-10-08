import XCTest

/// Opens Settings > Component gallery (Debug builds only) and attaches screenshots of every screen of it,
/// in light and dark.
@MainActor
final class GalleryTests: XCTestCase {
  private static let screenCount = 12

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func captureGallery(dark: Bool) {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData"]
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()

    let scheme = dark ? "dark" : "light"
    let settings = app.buttons["settings.open"].firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 10), "Missing settings button")
    settings.tap()

    let open = app.descendants(matching: .any)["gallery.open"].firstMatch
    XCTAssertTrue(open.waitForExistence(timeout: 10), "Missing gallery row")
    open.tap()
    XCTAssertTrue(
      app.navigationBars["Component gallery"].waitForExistence(timeout: 10), "Gallery did not open")

    let scroll = app.scrollViews.firstMatch
    XCTAssertTrue(scroll.waitForExistence(timeout: 5))
    for index in 1...Self.screenCount {
      attach(String(format: "gallery-%02d-%@", index, scheme))
      if index < Self.screenCount { scroll.swipeUp() }
    }
  }

  func testGalleryLight() { captureGallery(dark: false) }
  func testGalleryDark() { captureGallery(dark: true) }
}
