import XCTest

/// SPEC §19.5: the Privacy Policy and Support links in About, and the money wording.
@MainActor
final class ComplianceUITests: PracticeUITestCase {
  func testAboutHasPrivacyPolicyAndSupportLinks() {
    let app = launch(["-UITestResetData", "-UITestTab", "game"])
    app.buttons["settings.open"].firstMatch.tap()
    XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
    for id in ["settings.privacy", "settings.support"] {
      let link = element(app, id)
      var swipes = 0
      while !(link.exists && link.isHittable) && swipes < 8 {
        app.swipeUp()
        swipes += 1
      }
      XCTAssertTrue(link.exists, "Missing \(id)")
    }
    attach("settings-about-links")
  }

  func testMoneyIsNeverCalledPlayingForMoney() {
    let app = launch(["-UITestResetData", "-UITestTab", "game"])
    app.buttons["settings.open"].firstMatch.tap()
    XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.switches["Show amounts in money"].waitForExistence(timeout: 5)
      || app.staticTexts["Show amounts in money"].exists, "Settings should say \"Show amounts in money\"")
    XCTAssertFalse(app.staticTexts["Play for money"].exists)
    XCTAssertFalse(app.staticTexts["Track money"].exists)
    attach("settings-money")
  }
}
