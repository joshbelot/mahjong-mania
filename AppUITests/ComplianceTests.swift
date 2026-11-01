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

  private func captureSettings(dark: Bool = false, textSize: String? = nil, suffix: String) {
    let app = launch(["-UITestResetData", "-UITestTab", "game"], dark: dark, textSize: textSize)
    app.buttons["settings.open"].firstMatch.tap()
    let subtitle = app.staticTexts["The app only does the maths. No money is handled here."].firstMatch
    var swipes = 0
    while !(subtitle.exists && subtitle.isHittable) && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(subtitle.exists && subtitle.isHittable, "Money explanation must be visible")
    attach("compliance-money-\(suffix)")
    let support = element(app, "settings.support")
    swipes = 0
    while !(support.exists && support.isHittable) && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(support.exists && support.isHittable, "Support link must be visible")
    attach("compliance-about-\(suffix)")
  }

  func testComplianceScreensLight() { captureSettings(suffix: "light") }
  func testComplianceScreensDark() { captureSettings(dark: true, suffix: "dark") }
  func testComplianceScreensAX5() {
    captureSettings(textSize: "UICTContentSizeCategoryAccessibilityXXXL", suffix: "ax5")
  }


  func testAboutLinksOpenTheCorrectPages() {
    let app = launch(["-UITestResetData", "-UITestTab", "game"])
    app.buttons["settings.open"].firstMatch.tap()
    let support = element(app, "settings.support")
    var swipes = 0
    while !(support.exists && support.isHittable) && swipes < 10 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(support.isHittable)
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    element(app, "settings.privacy").tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
    XCTAssertTrue(safari.staticTexts["Privacy Policy"].firstMatch.waitForExistence(timeout: 20))
    attach("privacy-page-opened")
    app.activate()
    support.tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
    XCTAssertTrue(safari.staticTexts["Questions, bug reports and ideas are welcome."].firstMatch.waitForExistence(timeout: 20))
    attach("support-page-opened")
  }


  private func captureGameMoney(dark: Bool = false, textSize: String? = nil, suffix: String) {
    let flags = ["-UITestResetData", "-UITestTab", "game", "-UITestDemoData"]
    let app = launch(flags, dark: dark, textSize: textSize)
    tapWhenHittable(app, "game.start")
    let subtitle = element(app, "setup.money")
    var swipes = 0
    while !(subtitle.exists && subtitle.isHittable) && swipes < 12 {
      // At AX5 the fixed Start panel covers the lower half of the screen. Start the
      // drag in the visible content area rather than on that panel.
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.46))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      start.press(forDuration: 0.05, thenDragTo: end)
      swipes += 1
    }
    attach("compliance-setup-\(suffix)")
    XCTAssertTrue(subtitle.exists && subtitle.isHittable, "Setup money explanation must be visible")
    if textSize != nil {
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.46))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      start.press(forDuration: 0.05, thenDragTo: end)
      attach("compliance-setup-detail-\(suffix)")
    }
    app.terminate()
    let resumed = launch(flags, dark: dark, textSize: textSize)
    tapWhenHittable(resumed, "game.resume")
    tap(resumed, "score.menu")
    tap(resumed, "menu.rules")
    let rulesSubtitle = element(resumed, "rules.money")
    swipes = 0
    while !(rulesSubtitle.exists && rulesSubtitle.isHittable) && swipes < 16 {
      resumed.scrollViews.firstMatch.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(rulesSubtitle.exists && rulesSubtitle.isHittable, "Rules money explanation must be visible")
    attach("compliance-rules-\(suffix)")
    if textSize != nil {
      let start = resumed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
      let end = resumed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
      start.press(forDuration: 0.05, thenDragTo: end)
      attach("compliance-rules-detail-\(suffix)")
    }
  }

  func testGameMoneyScreensLight() { captureGameMoney(suffix: "light") }
  func testGameMoneyScreensDark() { captureGameMoney(dark: true, suffix: "dark") }
  func testGameMoneyScreensAX5() {
    captureGameMoney(textSize: "UICTContentSizeCategoryAccessibilityXXXL", suffix: "ax5")
  }

}
