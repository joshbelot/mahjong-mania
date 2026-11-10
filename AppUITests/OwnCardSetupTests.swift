import XCTest

/// Onboarding's "own card" choice through guided entry to an explicitly activated card (NEXT_WAVES §3.5).
@MainActor
final class OwnCardSetupTests: XCTestCase {
  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  @discardableResult
  private func tap(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    let target = element(app, id)
    XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing \(id)")
    var swipes = 0
    while !target.isHittable && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    swipes = 0
    while !target.isHittable && swipes < 12 {
      app.swipeDown()
      swipes += 1
    }
    XCTAssertTrue(target.isHittable, "\(id) is not tappable")
    target.tap()
    return target
  }

  private func run(dark: Bool, large: Bool) {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestShowOnboarding"]
    if dark { app.launchArguments += ["-UITestDark"] }
    if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
    app.launch()
    let scheme = (dark ? "dark" : "light") + (large ? "-ax5" : "")

    for _ in 0..<3 { tap(app, "onboarding.next") }
    tap(app, "card.own")
    attach("ownCard-onboarding-\(scheme)")
    tap(app, "onboarding.done")

    // Nonblocking reminder with the Practice fallback.
    XCTAssertTrue(element(app, "cardsetup.banner").waitForExistence(timeout: 10))
    attach("ownCard-banner-\(scheme)")
    tap(app, "cardsetup.start")
    attach("ownCard-method-chooser-\(scheme)")
    XCTAssertTrue(element(app, "method.import").waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "method.qr").exists)
    tap(app, "method.build")

    // Name the card, then add the first hand with the guided editor.
    let name = app.textFields["Card name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("My card")
    app.alerts.buttons["Create"].tap()
    let add = app.buttons["Add hand"].firstMatch
    XCTAssertTrue(add.waitForExistence(timeout: 10), "No Add hand button on the empty card")
    add.tap()
  }

  func testOwnCardFlowLight() { guidedFlow(dark: false, large: false) }
  func testOwnCardFlowDark() { guidedFlow(dark: true, large: false) }
  func testOwnCardFlowLargestText() { guidedFlow(dark: false, large: true) }

  private func guidedFlow(dark: Bool, large: Bool) {
    let scheme = (dark ? "dark" : "light") + (large ? "-ax5" : "")
    run(dark: dark, large: large)
    let app = XCUIApplication()
    // An empty card cannot be saved yet.
    XCTAssertTrue(element(app, "guided.addGroup.0").waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["editor.save"].isEnabled)
    attach("ownCard-guided-empty-\(scheme)")
    for _ in 0..<7 { tap(app, "guided.addGroup.0") }
    XCTAssertFalse(app.buttons["editor.save"].isEnabled, "Seven identical pairs are not a real hand")
    // Make the pairs 11 22 33 44 55 66 77 in suit A.
    for index in 1..<7 {
      let option = app.buttons["\(index + 1)"].firstMatch
      for attempt in 0..<3 where !option.exists {
        if attempt > 0 { app.swipeDown() }
        tap(app, "guided.number.0.\(index)")
        _ = option.waitForExistence(timeout: 3)
      }
      XCTAssertTrue(option.exists, "No menu option \(index + 1)")
      option.tap()
    }
    XCTAssertTrue(element(app, "editor.valid").waitForExistence(timeout: 5), "The hand should now be valid")
    attach("ownCard-guided-valid-\(scheme)")
    tap(app, "editor.save")

    // The new card is not active until the player says so.
    XCTAssertTrue(element(app, "card.activateBanner").waitForExistence(timeout: 10))
    attach("ownCard-activate-\(scheme)")
    tap(app, "card.activate")
    XCTAssertFalse(element(app, "card.activateBanner").waitForNonExistence(timeout: 5) == false)
    XCTAssertFalse(element(app, "cardsetup.banner").exists, "Activating a usable card completes setup")
  }
}
