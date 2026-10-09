import XCTest

/// The Helper tab: assist-level gating (Off hides the tab, Peek needs a tap, Coach shows everything),
/// the Charleston pass suggestions, the call checker's three Phase 4 scenarios, exposures, seen tiles
/// and Scout, with screenshots in light and dark.
@MainActor
final class HelperTests: XCTestCase {
  /// A hand with a few pairs and a joker-free spread; plenty of hands are a few tiles away.
  private static let sampleRack = "1C,2C,3C,5D,5D,6D,6D,6D,N,R,0,F,J"
  /// Even Pairs (X = Bams, Y = Dots) one 4 Bam short: calling a 4 Bam is Mahjong.
  private static let mahjongRack = "F,F,2B,2B,4B,6B,6B,8B,8B,2D,4D,6D,8D"
  /// Even Climb (Bams) missing one 6 Bam and one 8 Bam.
  private static let climbRack = "2B,2B,2B,4B,4B,4B,4B,6B,6B,8B,8B,8B"
  private static let jokerRack = "J,J,J,1C,2C,3C,4C,5D,5D,N,E,R,0"

  private let dash = "\u{2014}"

  // MARK: Helpers

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func scheme(_ dark: Bool) -> String { dark ? "dark" : "light" }

  private func launch(
    assist: String = "peek", rack: String? = nil, mode: String? = nil, dark: Bool = false,
    openHelper: Bool = true
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UITestResetData", "-UITestAssist", assist]
    if let rack { app.launchArguments += ["-UITestHelperRack", rack] }
    if let mode { app.launchArguments += ["-UITestHelperMode", mode] }
    if dark { app.launchArguments += ["-UITestDark"] }
    app.launch()
    if openHelper {
      let tab = app.tabBars.buttons["Helper"]
      XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing Helper tab")
      tab.tap()
      XCTAssertTrue(app.navigationBars["Helper"].waitForExistence(timeout: 5))
    }
    return app
  }

  private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func withLabel(_ app: XCUIApplication, containing text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  private func waitForGone(_ target: XCUIElement) -> Bool {
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: target)
    return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
  }

  private func expectExists(
    _ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(element(app, id).waitForExistence(timeout: 10), "Missing \(id)", file: file, line: line)
  }

  /// Taps an element, scrolling the page up until it can be hit.
  private func tap(
    _ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    let target = element(app, id)
    XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing \(id)", file: file, line: line)
    var swipes = 0
    while !target.isHittable && swipes < 4 {
      app.swipeUp()
      swipes += 1
    }
    swipes = 0
    while !target.isHittable && swipes < 8 {
      app.swipeDown()
      swipes += 1
    }
    XCTAssertTrue(target.isHittable, "\(id) is not tappable", file: file, line: line)
    target.tap()
  }

  /// Folds the keyboard away so the results have the whole screen.
  private func collapseKeyboard(_ app: XCUIApplication) {
    tap(app, "helper.keyboard.toggle")
    XCTAssertTrue(waitForGone(element(app, "key.1C")), "The keyboard should fold away")
  }

  private func selectMode(_ app: XCUIApplication, _ title: String) {
    let button = app.segmentedControls.buttons[title].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing mode \(title)")
    button.tap()
  }

  private func assertNoJokerPassed(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    for index in 0..<3 {
      let row = element(app, "pass.row.\(index)")
      XCTAssertTrue(row.waitForExistence(timeout: 10), "Missing pass suggestion \(index)", file: file, line: line)
      XCTAssertFalse(row.label.hasPrefix("Joker"), "A joker was suggested: \(row.label)", file: file, line: line)
    }
    XCTAssertFalse(element(app, "pass.row.3").exists, "Only three tiles should be suggested", file: file, line: line)
  }

  // MARK: Assist Off

  private func assistOff(dark: Bool) {
    let app = launch(assist: "off", dark: dark, openHelper: false)
    XCTAssertTrue(app.tabBars.buttons["Game"].waitForExistence(timeout: 10), "Missing Game tab")
    XCTAssertTrue(app.tabBars.buttons["Cards"].exists)
    XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
    XCTAssertFalse(app.tabBars.buttons["Helper"].exists, "Assist Off must hide the Helper tab")
    attach("helper-assist-off-\(scheme(dark))")
  }

  func testAssistOffHidesTheTabLight() { assistOff(dark: false) }
  func testAssistOffHidesTheTabDark() { assistOff(dark: true) }

  // MARK: Peek

  private func peek(dark: Bool) {
    let app = launch(assist: "peek", rack: Self.sampleRack, dark: dark)
    expectExists(app, "rack.count")
    attach("helper-peek-keyboard-\(scheme(dark))")
    collapseKeyboard(app)
    expectExists(app, "helper.results.reveal")
    expectExists(app, "helper.suggest")
    XCTAssertFalse(element(app, "result.0").exists, "Peek must not show hands before a tap")
    XCTAssertFalse(element(app, "pass.row.0").exists, "Peek must not suggest before a tap")
    XCTAssertFalse(element(app, "coach.tip").exists, "Tips are for Coach only")
    attach("helper-peek-collapsed-\(scheme(dark))")

    tap(app, "helper.results.reveal")
    expectExists(app, "result.0")
    expectExists(app, "result.2")
    XCTAssertFalse(element(app, "result.3").exists, "Peek lists the top three hands")
    XCTAssertFalse(element(app, "helper.results.showall").exists)

    tap(app, "result.0")
    let value = element(app, "result.0").value as? String ?? ""
    XCTAssertTrue(value.hasPrefix("Need"), "Tapping a hand should show what is missing, got '\(value)'")
    attach("helper-peek-results-\(scheme(dark))")

    tap(app, "helper.suggest")
    assertNoJokerPassed(app)
    attach("helper-peek-suggestions-\(scheme(dark))")
  }

  func testPeekRequiresATapLight() { peek(dark: false) }
  func testPeekRequiresATapDark() { peek(dark: true) }

  // MARK: Coach

  private func coach(dark: Bool) {
    let app = launch(assist: "coach", rack: Self.sampleRack, dark: dark)
    collapseKeyboard(app)
    expectExists(app, "result.0")
    expectExists(app, "result.7")
    XCTAssertFalse(element(app, "result.8").exists, "Coach lists eight hands before Show all")
    expectExists(app, "pass.row.0")
    expectExists(app, "pass.row.2")
    expectExists(app, "pass.focus")
    expectExists(app, "coach.tip")
    XCTAssertFalse(element(app, "helper.results.reveal").exists)
    XCTAssertFalse(element(app, "helper.suggest").exists)
    attach("helper-coach-\(scheme(dark))")

    tap(app, "helper.results.showall")
    expectExists(app, "result.20")
    attach("helper-coach-all-\(scheme(dark))")
  }

  func testCoachShowsEverythingLight() { coach(dark: false) }
  func testCoachShowsEverythingDark() { coach(dark: true) }

  func testAssistChipSwitchesToCoach() {
    let app = launch(assist: "peek", rack: Self.sampleRack)
    collapseKeyboard(app)
    XCTAssertFalse(element(app, "result.0").exists)
    tap(app, "helper.assist")
    let coachItem = app.buttons["Coach"].firstMatch
    XCTAssertTrue(coachItem.waitForExistence(timeout: 5), "Missing Coach menu item")
    attach("helper-assist-menu-light")
    coachItem.tap()
    expectExists(app, "result.0")
    expectExists(app, "pass.row.0")
  }

  // MARK: Empty state and Charleston

  func testEmptyStateDealsAHandAndNeverPassesAJoker() {
    let app = launch(assist: "coach")
    expectExists(app, "helper.deal")
    attach("helper-empty-light")
    tap(app, "helper.deal")
    expectExists(app, "rack.count")
    XCTAssertEqual(element(app, "rack.count").label, "13 of 14 tiles")
    assertNoJokerPassed(app)
    attach("helper-charleston-dealt-light")
  }

  func testPassSuggestionsSkipJokersInDark() {
    let app = launch(assist: "coach", rack: Self.jokerRack, dark: true)
    assertNoJokerPassed(app)
    collapseKeyboard(app)
    attach("helper-charleston-jokers-dark")
  }

  func testEmptyStateDark() {
    let app = launch(assist: "peek", dark: true)
    expectExists(app, "helper.deal")
    attach("helper-empty-dark")
  }

  func testCardPickerListsTheCards() {
    let app = launch(assist: "peek")
    tap(app, "helper.card")
    expectExists(app, "helper.card.row.0")
    attach("helper-card-picker-light")
    tap(app, "helper.card.row.0")
    XCTAssertTrue(waitForGone(element(app, "helper.card.row.0")), "Choosing a card closes the picker")
  }

  // MARK: Call checker (the three Phase 4 scenarios)

  private func openCallChecker(_ app: XCUIApplication) {
    selectMode(app, "Playing")
    collapseKeyboard(app)
    tap(app, "helper.call")
    expectExists(app, "call.prompt")
  }

  func testCallCheckerSaysMahjong() {
    let app = launch(assist: "peek", rack: Self.mahjongRack, mode: "playing")
    openCallChecker(app)
    tap(app, "key.4B")
    let verdict = element(app, "call.verdict.0")
    XCTAssertTrue(verdict.waitForExistence(timeout: 10), "Missing verdict")
    XCTAssertTrue(verdict.label.contains("Call it \(dash) that's Mahjong!"), "Got '\(verdict.label)'")
    attach("helper-call-mahjong-light")
  }

  func testCallCheckerExposesAndLetsGo() {
    let app = launch(assist: "coach", rack: Self.climbRack, mode: "playing", dark: true)
    openCallChecker(app)

    tap(app, "key.6B")
    let expose = withLabel(app, containing: "Expose a pung \(dash) you'd be 1 away")
    XCTAssertTrue(expose.waitForExistence(timeout: 10), "Expected an expose verdict with the right distance")
    attach("helper-call-expose-dark")

    tap(app, "key.N")
    let letGo = element(app, "call.verdict.none")
    XCTAssertTrue(letGo.waitForExistence(timeout: 10), "A useless tile should give no verdict")
    XCTAssertTrue(letGo.label.contains("Let it go \(dash) it doesn't help your top hands."))
    XCTAssertFalse(element(app, "call.verdict.0").exists)
    attach("helper-call-letgo-dark")
  }

  // MARK: Playing: exposures and seen tiles

  private func playing(dark: Bool) {
    let app = launch(assist: "coach", rack: "2B,2B,4B,4B,4B,6B,8B,8B,8B,N,E,R,0", mode: "playing", dark: dark)
    collapseKeyboard(app)
    tap(app, "helper.exposures.add")
    expectExists(app, "exposure.confirm")
    tap(app, "key.6B")
    attach("helper-exposure-sheet-\(scheme(dark))")
    tap(app, "exposure.confirm")
    expectExists(app, "helper.exposures.exposure.0")

    tap(app, "seen.toggle")
    tap(app, "seen.key.5D")
    tap(app, "seen.key.5D")
    let seenLabel = element(app, "seen.toggle").label
    XCTAssertTrue(seenLabel.contains("2 seen"), "Got '\(seenLabel)'")
    attach("helper-playing-\(scheme(dark))")

    tap(app, "helper.exposures.exposure.0")
    XCTAssertTrue(waitForGone(element(app, "helper.exposures.exposure.0")), "Tapping an exposure removes it")
  }

  func testPlayingExposuresAndSeenTilesLight() { playing(dark: false) }
  func testPlayingExposuresAndSeenTilesDark() { playing(dark: true) }

  // MARK: Scout

  private func scout(dark: Bool) {
    let app = launch(assist: "coach", mode: "scout", dark: dark)
    expectExists(app, "scout.empty")
    attach("helper-scout-empty-\(scheme(dark))")

    tap(app, "scout.0.add")
    expectExists(app, "exposure.confirm")
    tap(app, "key.6D")
    tap(app, "exposure.confirm")
    expectExists(app, "scout.0.exposure.0")
    expectExists(app, "scout.lines.Right")
    expectExists(app, "danger.row.0")
    XCTAssertFalse(element(app, "scout.empty").exists)
    XCTAssertTrue(
      element(app, "danger.row.0").label.contains("danger"), "Danger rows should name the level")
    attach("helper-scout-\(scheme(dark))")

    app.swipeUp()
    attach("helper-scout-safer-\(scheme(dark))")
  }

  func testScoutLight() { scout(dark: false) }
  func testScoutDark() { scout(dark: true) }
}
