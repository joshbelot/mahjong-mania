import XCTest

/// Sharing a card by QR code (SPEC §17.7): a link opens the pre-filled Import screen, bad links are
/// explained, and a user card shows its QR code.
@MainActor
final class CardQRTests: XCTestCase {
  /// A two-hand card named "Club Card \u{2014} QR test", encoded the way the app does it.
  private static let cardURL = "mahjongmania://card?v=1&d=U1RwzilNUnBOLEpReNQwRSEwSKEktbiES7EyNbFIwcjAyIxLX1-hpDxfISMxL6VYIS2_SKEkIxWkLjO3IL-oRCHUE6JDWcG1LDWvmMvIyEi_QsEECICUmZkZkLQAAiBlrWBkCiQigBikFGhzZm4Sl5ubghFMj34lUAeQwKHBKT8_OxXoCi4A"

  private func launch(url: String, dark: Bool = false) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData", "-UITestOpenURL", url]
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()
    return app
  }

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
    XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(id)")
    element.tap()
  }

  private func importThenShowQR(dark: Bool) {
    let scheme = dark ? "dark" : "light"
    let app = launch(url: Self.cardURL, dark: dark)
    let summary = el(app, "import.summary")
    XCTAssertTrue(summary.waitForExistence(timeout: 15), "The import screen should open pre-filled")
    XCTAssertTrue(summary.label.contains("2"), "Two hands should be found, got '\(summary.label)'")
    XCTAssertFalse(el(app, "import.problems").exists, "Every line should be fine")
    attach("qr-import-\(scheme)")
    tap(app, "import.confirm")

    // The new card opens in the Cards tab.
    tap(app, "card.menu")
    tap(app, "card.qr")
    let image = el(app, "qr.image")
    XCTAssertTrue(image.waitForExistence(timeout: 10), "Missing the QR code")
    XCTAssertTrue(el(app, "qr.name").label.contains("Club Card"))
    XCTAssertEqual(el(app, "qr.instruction").label, "Scan with your iPhone Camera to add this card")
    XCTAssertTrue(el(app, "qr.share").exists, "Missing the Share image button")
    attach("qr-sheet-\(scheme)")
    tap(app, "qr.done")
    XCTAssertTrue(el(app, "qr.image").waitForNonExistence(timeout: 10))
  }

  func testLinkOpensImportAndTheCardShowsItsQRLight() { importThenShowQR(dark: false) }
  func testLinkOpensImportAndTheCardShowsItsQRDark() { importThenShowQR(dark: true) }

  func testABrokenLinkIsExplained() {
    let app = launch(url: "mahjongmania://card?v=1&d=!!!")
    let alert = app.alerts["Can't open this QR code"]
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "Expected an alert")
    XCTAssertTrue(alert.staticTexts["This QR code isn't a Mahjong Mania card, or it's damaged."].exists)
    attach("qr-bad-link-light")
    alert.buttons["OK"].tap()
    XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
  }

  func testANewerVersionAsksForAnUpdate() {
    let app = launch(url: Self.cardURL.replacingOccurrences(of: "v=1", with: "v=2"))
    let alert = app.alerts["Can't open this QR code"]
    XCTAssertTrue(alert.waitForExistence(timeout: 15), "Expected an alert")
    XCTAssertTrue(
      alert.staticTexts[
        "This card was shared from a newer version of Mahjong Mania. Update the app to import it."
      ].exists)
  }
}
