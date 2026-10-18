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
    tapWhenHittable(app, "placement.regular")
    attach("onboarding-2-placement-light")

    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.coach")
    attach("onboarding-3-assist-light")

    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.practice")
    attach("onboarding-4-card-light")

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
    tapWhenHittable(app, "placement.basics")
    attach("onboarding-2-placement-dark")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.peek")
    attach("onboarding-3-assist-dark")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.own")
    attach("onboarding-4-card-dark")
    app.buttons["onboarding.skip"].tap()
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 10), "Skip did not finish")
  }

  func testOnboardingAtAccessibilitySize() {
    let app = launch(["-UITestShowOnboarding"], textSize: Self.accessibilityM)
    XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    attach("onboarding-1-welcome-ax-light")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "placement.new")
    attach("onboarding-2-placement-ax-light")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "assist.coach")
    attach("onboarding-3-assist-ax-light")
    app.buttons["onboarding.next"].tap()
    tapWhenHittable(app, "card.later")
    attach("onboarding-4-card-ax-light")
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
  }

  private func launchTour(dark: Bool = false, textSize: String? = nil) -> XCUIApplication {
    launch(["-UITestResetData"], dark: dark, textSize: textSize)
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

    // The drills live in Practice → Free play; Learn points there.
    tapElement(app, "learn.practice")
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 5), "Learn did not open Practice")
    attach("learn-to-practice-\(tag)")
  }
}
