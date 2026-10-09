import XCTest

/// Onboarding (fresh install, choices persist across a relaunch) and the Learn tab: every topic, the
/// glossary and both drills, with screenshots in light, dark and at accessibility text sizes.
@MainActor
final class LearnOnboardingTests: XCTestCase {
  private static let accessibilityM = "UICTContentSizeCategoryAccessibilityM"
  private static let accessibilityXL = "UICTContentSizeCategoryAccessibilityXL"

  // MARK: Helpers

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func launch(
    _ flags: [String] = ["-UITestResetData"], dark: Bool = false, textSize: String? = nil
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += flags
    if dark { app.launchArguments += ["-UITestDark"] }
    if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  /// Taps an element that exists in the hierarchy; XCTest scrolls it into view first.
  @discardableResult
  private func tapElement(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line)
    -> XCUIElement
  {
    let target = element(app, id)
    XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing \(id)", file: file, line: line)
    target.tap()
    return target
  }

  /// Waits until an element is on screen, for controls that sit on another page of a pager.
  private func tapWhenHittable(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
    let target = element(app, id)
    var swipes = 0
    while !(target.exists && target.isHittable) && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    let hittable = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isHittable == true"), object: target)
    XCTAssertEqual(
      XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "\(id) never became tappable",
      file: file, line: line)
    target.tap()
  }

  private func waitForGone(_ target: XCUIElement) -> Bool {
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: target)
    return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
  }

  private func openLearn(_ app: XCUIApplication) {
    let tab = app.tabBars.buttons["Learn"]
    XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing Learn tab")
    tab.tap()
    XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
  }

  private func backToLearn(_ app: XCUIApplication) {
    let back = app.navigationBars.buttons["Learn"].firstMatch
    XCTAssertTrue(back.waitForExistence(timeout: 5), "Missing back button")
    back.tap()
    XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
  }

  // MARK: Onboarding

  func testOnboardingChoicesPersistAcrossRelaunch() {
    let app = launch(["-UITestShowOnboarding"])
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10), "Onboarding did not show")
    XCTAssertFalse(app.tabBars.buttons["Game"].exists)
    attach("onboarding-1-welcome-light")

    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.coach")
    attach("onboarding-2-assist-light")

    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.practice")
    attach("onboarding-3-card-light")

    app.buttons["onboarding.done"].tap()
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 10), "Did not reach the app")
    XCTAssertTrue(app.tabBars.buttons["Game"].isSelected, "Should land on the Game tab")
    XCTAssertFalse(app.buttons["onboarding.next"].exists)
    Thread.sleep(forTimeInterval: 1)
    app.terminate()

    // Relaunch with no flags: the data directory is kept, so onboarding must not return.
    let again = launch([])
    XCTAssertTrue(again.tabBars.buttons["Game"].waitForExistence(timeout: 10), "Onboarding came back")
    XCTAssertTrue(again.tabBars.buttons["Game"].isSelected, "Should land on the Game tab")
    openLearn(again)
    // The Coach level was saved, so Learn shows a coach tip.
    XCTAssertTrue(element(again, "coach.tip").waitForExistence(timeout: 5), "Coach level was not saved")
    attach("learn-home-coach-tip-light")
    tapElement(again, "coach.tip.dismiss")
    XCTAssertTrue(waitForGone(element(again, "coach.tip")), "Tip was not dismissed")
  }

  func testOnboardingDarkAndSkip() {
    let app = launch(["-UITestShowOnboarding"], dark: true)
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    attach("onboarding-1-welcome-dark")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.peek")
    attach("onboarding-2-assist-dark")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.own")
    attach("onboarding-3-card-dark")
    app.buttons["onboarding.skip"].tap()
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 10), "Skip did not finish")
  }

  func testOnboardingAtAccessibilitySize() {
    let app = launch(["-UITestShowOnboarding"], textSize: Self.accessibilityM)
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    attach("onboarding-1-welcome-ax-light")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.coach")
    attach("onboarding-2-assist-ax-light")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.later")
    attach("onboarding-3-card-ax-light")
  }

  // MARK: Learn

  func testLearnTourLight() { learnTour(app: launchTour(), tag: "light") }

  func testLearnTourDark() { learnTour(app: launchTour(dark: true), tag: "dark") }

  func testLearnTourAccessibilityLight() {
    learnTour(app: launchTour(textSize: Self.accessibilityM), tag: "ax-light")
  }

  func testLearnTourAccessibilityDark() {
    learnTour(app: launchTour(dark: true, textSize: Self.accessibilityM), tag: "ax-dark")
  }

  func testLearnAtLargestSizes() {
    let app = launchTour(textSize: Self.accessibilityXL)
    openLearn(app)
    attach("axxl-learn-home")
    tapElement(app, "learn.topic.notation")
    attach("axxl-topic-notation")
    app.swipeUp()
    attach("axxl-topic-notation-2")
    backToLearn(app)
    tapElement(app, "learn.drill.charleston")
    XCTAssertTrue(element(app, "drill.seed").waitForExistence(timeout: 10))
    attach("axxl-charleston")
    tapElement(app, "charleston.tile.12")
    attach("axxl-charleston-joker")
  }

  /// Seed 3 deals exactly one joker (it sorts last, at position 12), so the joker rule can be tested.
  private func launchTour(dark: Bool = false, textSize: String? = nil) -> XCUIApplication {
    launch(["-UITestResetData", "-UITestDrillSeed", "3"], dark: dark, textSize: textSize)
  }

  private func learnTour(app: XCUIApplication, tag: String) {
    openLearn(app)
    attach("learn-home-\(tag)")
    app.swipeUp()
    attach("learn-home-\(tag)-2")
    app.swipeDown()

    for id in ["rules", "tiles", "reading", "notation"] {
      tapElement(app, "learn.topic.\(id)")
      XCTAssertTrue(
        app.navigationBars.buttons["Learn"].firstMatch.waitForExistence(timeout: 5), "Topic \(id) did not open")
      if id == "rules" || id == "notation" {
        attach("learn-topic-\(id)-\(tag)")
        app.swipeUp()
        attach("learn-topic-\(id)-\(tag)-2")
      }
      backToLearn(app)
    }

    tapElement(app, "learn.glossary")
    XCTAssertTrue(app.navigationBars["Glossary"].waitForExistence(timeout: 5))
    attach("learn-glossary-\(tag)")
    backToLearn(app)

    pickAHandTour(app, tag: tag)
    charlestonTour(app, tag: tag)
  }

  private func pickAHandTour(_ app: XCUIApplication, tag: String) {
    tapElement(app, "learn.drill.pick")
    let seed = element(app, "drill.seed")
    XCTAssertTrue(seed.waitForExistence(timeout: 10), "Pick-a-Hand did not open")
    let seedText = seed.label
    XCTAssertTrue(seedText.contains("3"), "Expected the forced seed in \(seedText)")
    attach("drill-pick-\(tag)-1")

    tapElement(app, "pick.line.0")
    XCTAssertTrue(element(app, "drill.result").waitForExistence(timeout: 10), "No result shown")
    attach("drill-pick-\(tag)-2")
    app.swipeUp()
    attach("drill-pick-\(tag)-3")

    // "Try again" replays the same deal.
    tapElement(app, "drill.tryagain")
    XCTAssertTrue(element(app, "pick.line.0").waitForExistence(timeout: 5), "Did not return to picking")
    XCTAssertEqual(element(app, "drill.seed").label, seedText, "Try again changed the deal")

    tapElement(app, "pick.line.1")
    XCTAssertTrue(element(app, "drill.result").waitForExistence(timeout: 10))
    tapElement(app, "drill.next")
    XCTAssertTrue(element(app, "pick.line.0").waitForExistence(timeout: 5))
    XCTAssertNotEqual(element(app, "drill.seed").label, seedText, "Next deal kept the same deal")
    backToLearn(app)
  }

  private func charlestonTour(_ app: XCUIApplication, tag: String) {
    tapElement(app, "learn.drill.charleston")
    let seed = element(app, "drill.seed")
    XCTAssertTrue(seed.waitForExistence(timeout: 10), "Charleston Pass did not open")
    let seedText = seed.label
    attach("drill-charleston-\(tag)-1")

    // The joker cannot be selected.
    tapElement(app, "charleston.tile.12")
    XCTAssertTrue(element(app, "charleston.message").waitForExistence(timeout: 5), "No joker message")
    XCTAssertTrue(
      element(app, "charleston.count").label.contains("0 of 3"), "The joker should not be selected")
    attach("drill-charleston-\(tag)-joker")

    tapElement(app, "charleston.tile.0")
    tapElement(app, "charleston.tile.1")
    tapElement(app, "charleston.tile.2")
    XCTAssertTrue(element(app, "charleston.count").label.contains("3 of 3"))
    attach("drill-charleston-\(tag)-2")

    tapElement(app, "charleston.submit")
    XCTAssertTrue(element(app, "drill.result").waitForExistence(timeout: 10), "No result shown")
    attach("drill-charleston-\(tag)-3")
    app.swipeUp()
    attach("drill-charleston-\(tag)-4")

    tapElement(app, "drill.tryagain")
    XCTAssertTrue(element(app, "charleston.submit").waitForExistence(timeout: 5))
    XCTAssertEqual(element(app, "drill.seed").label, seedText, "Try again changed the deal")
    XCTAssertTrue(element(app, "charleston.count").label.contains("0 of 3"))
    backToLearn(app)
  }
}
