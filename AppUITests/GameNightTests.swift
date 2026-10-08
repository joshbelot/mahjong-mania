import XCTest

/// Plays a scripted game night with four players: creates the players, starts a session, records
/// hands (discard win, self-pick, jokerless win, wall game, adjustment), edits a hand, undoes one,
/// relaunches the app (data must persist) and checks the summary's settle-up lines.
@MainActor
final class GameNightTests: XCTestCase {
  private let players = ["Alex", "Bea", "Cy", "Dee"]
  /// Counts the taps made through `tap(_:_:)`, so the 5-tap record path can be asserted.
  private var tapCount = 0

  // MARK: Helpers

  private func launch(dark: Bool, reset: Bool = true) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    if reset { app.launchArguments += ["-UITestResetData"] }
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

  /// Any element with this accessibility identifier.
  private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func tap(_ element: XCUIElement, _ what: String) {
    XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(what)")
    element.tap()
    tapCount += 1
  }

  private func tapID(_ app: XCUIApplication, _ id: String) {
    tap(el(app, id), id)
  }

  /// Opens the game menu and taps one item (by identifier, falling back to its label).
  private func menu(_ app: XCUIApplication, id: String, label: String) {
    tapID(app, "score.menu")
    let byID = app.buttons[id]
    if byID.waitForExistence(timeout: 3) {
      byID.tap()
    } else {
      let byLabel = app.buttons[label]
      XCTAssertTrue(byLabel.waitForExistence(timeout: 5), "Missing menu item \(label)")
      byLabel.tap()
    }
  }

  private func dismissKeyboardTip(_ app: XCUIApplication) {
    let tip = app.buttons["Continue"]
    if tip.waitForExistence(timeout: 1) { tip.tap() }
  }

  static func value(ofSpoken text: String) -> Int? {
    let words = text.split(separator: " ").map(String.init)
    guard let first = words.first else { return nil }
    if first == "plus", words.count > 1 { return Int(words[1]) }
    if first == "minus", words.count > 1 { return Int(words[1]).map { -$0 } }
    return Int(first)
  }

  /// Waits until every `score.<name>` shows the expected total.
  private func expectScores(_ app: XCUIApplication, _ expected: [String: Int], _ context: String) {
    let deadline = Date().addingTimeInterval(10)
    var actual: [String: Int] = [:]
    repeat {
      actual = [:]
      for name in expected.keys {
        let element = el(app, "score.\(name)")
        if element.exists, let value = Self.value(ofSpoken: element.label) { actual[name] = value }
      }
      if actual == expected { return }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    XCTAssertEqual(actual, expected, context)
  }

  private func expectDealer(_ app: XCUIApplication, _ dealer: String, _ context: String) {
    XCTAssertTrue(el(app, "dealer.\(dealer)").waitForExistence(timeout: 10), "\(context): \(dealer) should be East")
    for name in players where name != dealer {
      XCTAssertFalse(el(app, "dealer.\(name)").exists, "\(context): \(name) should not be East")
    }
  }

  private func waitForSheetToClose(_ app: XCUIApplication, _ id: String) {
    XCTAssertTrue(el(app, id).waitForNonExistence(timeout: 10), "\(id) did not close")
  }

  // MARK: Flow pieces

  private func createPlayersAndStart(_ app: XCUIApplication, money: Bool, scheme: String) {
    tapID(app, "game.start")
    tapID(app, "setup.addPlayerToggle")
    for (index, name) in players.enumerated() {
      let field = el(app, "setup.newName")
      tap(field, "name field")
      if index == 0 { dismissKeyboardTip(app) }
      field.typeText(name)
      tapID(app, "setup.addPlayer")
      XCTAssertTrue(el(app, "setup.player.\(name)").waitForExistence(timeout: 5), "Chip for \(name)")
    }
    if money { tapID(app, "setup.money") }
    attach("game-setup-\(scheme)")
    tapID(app, "setup.start")
    XCTAssertTrue(el(app, "score.Alex").waitForExistence(timeout: 10), "Scoreboard did not open")
  }

  /// winner -> Discard -> thrower -> points chip -> Save.
  private func recordDiscard(
    _ app: XCUIApplication, winner: String, thrower: String, points: Int, jokerless: Bool = false
  ) {
    tapID(app, "score.record")
    tapID(app, "record.winner.\(winner)")
    tapID(app, "record.how.discard")
    tapID(app, "record.thrower.\(thrower)")
    if jokerless { tapID(app, "record.jokerless") }
    tapID(app, "record.points.\(points)")
    tapID(app, "record.save")
    waitForSheetToClose(app, "record.save")
  }

  private func recordSelfPick(_ app: XCUIApplication, winner: String, points: Int) {
    tapID(app, "score.record")
    tapID(app, "record.winner.\(winner)")
    tapID(app, "record.how.self")
    tapID(app, "record.points.\(points)")
    tapID(app, "record.save")
    waitForSheetToClose(app, "record.save")
  }

  private func recordWall(_ app: XCUIApplication) {
    tapID(app, "score.wall")
    tap(app.buttons["Record wall game"], "wall game confirmation")
  }

  private func endGameNight(_ app: XCUIApplication) {
    menu(app, id: "menu.end", label: "End game night")
    let confirm = app.buttons["End game night"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Missing end confirmation")
    confirm.tap()
    XCTAssertTrue(el(app, "summary.done").waitForExistence(timeout: 10), "Summary did not open")
  }

  // MARK: Tests

  func testScriptedGameNightLight() {
    let app = launch(dark: false)
    XCTAssertTrue(el(app, "game.start").waitForExistence(timeout: 10))
    attach("game-home-light")

    createPlayersAndStart(app, money: true, scheme: "light")
    XCTAssertTrue(el(app, "log.empty").waitForExistence(timeout: 5), "Empty hand log message")
    expectScores(app, ["Alex": 0, "Bea": 0, "Cy": 0, "Dee": 0], "fresh game")
    expectDealer(app, "Alex", "start")
    attach("game-scoreboard-empty-light")

    // Hand 1: Alex wins on Bea's discard, 25 points. The experienced path is five taps:
    // 1 winner, 2 Discard, 3 thrower, 4 the 25 chip, 5 Save.
    tapID(app, "score.record")
    let save = el(app, "record.save")
    XCTAssertTrue(save.waitForExistence(timeout: 10))
    XCTAssertFalse(save.isEnabled, "Save must be disabled until the hand is complete")
    tapCount = 0
    tapID(app, "record.winner.Alex")  // tap 1
    tapID(app, "record.how.discard")  // tap 2
    tapID(app, "record.thrower.Bea")  // tap 3
    XCTAssertFalse(save.isEnabled, "Points are still missing")
    tapID(app, "record.points.25")  // tap 4
    XCTAssertTrue(save.isEnabled, "Save is enabled after four taps")
    attach("game-record-light")
    app.swipeUp()
    attach("game-record-preview-light")
    tapID(app, "record.save")  // tap 5
    XCTAssertEqual(tapCount, 5, "Record-hand path must be exactly five taps")
    waitForSheetToClose(app, "record.save")
    expectScores(app, ["Alex": 100, "Bea": -50, "Cy": -25, "Dee": -25], "after hand 1")
    expectDealer(app, "Bea", "after hand 1")
    XCTAssertEqual(el(app, "money.Alex").label, "+$1.00")

    // Hand 2: Bea self-picks 30 (everyone pays 60).
    recordSelfPick(app, winner: "Bea", points: 30)
    expectScores(app, ["Alex": 40, "Bea": 130, "Cy": -85, "Dee": -85], "after hand 2")
    expectDealer(app, "Cy", "after hand 2")

    // Hand 3: Cy wins jokerless on Dee's discard, hand chosen from the Practice Card (Even Climb, 25).
    tapID(app, "score.record")
    tapID(app, "record.winner.Cy")
    tapID(app, "record.how.discard")
    tapID(app, "record.thrower.Dee")
    tapID(app, "record.chooseHand")
    // The list is lazy, so search for the hand instead of scrolling to it.
    let search = app.searchFields.firstMatch
    tap(search, "hand search field")
    search.typeText("Even Climb")
    let line = el(app, "pick.line.Even Climb")
    XCTAssertTrue(line.waitForExistence(timeout: 10), "Even Climb in the hand picker")
    attach("game-picker-light")
    line.tap()
    XCTAssertTrue(line.waitForNonExistence(timeout: 10), "Hand picker did not close")
    tapID(app, "record.jokerless")
    XCTAssertTrue(el(app, "record.points.25").waitForExistence(timeout: 5))
    tapID(app, "record.save")
    waitForSheetToClose(app, "record.save")
    expectScores(app, ["Alex": -10, "Bea": 80, "Cy": 115, "Dee": -185], "after hand 3 (jokerless)")
    expectDealer(app, "Dee", "after hand 3")

    // Hand 4: wall game. No payments, the deal passes to Alex.
    recordWall(app)
    expectScores(app, ["Alex": -10, "Bea": 80, "Cy": 115, "Dee": -185], "after the wall game")
    expectDealer(app, "Alex", "after the wall game")

    // Hand 5: adjustment of 10 points from Dee to Alex. The dealer does not change.
    menu(app, id: "menu.adjustment", label: "Adjustment")
    tapID(app, "adjust.from.Dee")
    tapID(app, "adjust.to.Alex")
    tapID(app, "adjust.points.10")
    tapID(app, "adjust.save")
    waitForSheetToClose(app, "adjust.save")
    expectScores(app, ["Alex": 0, "Bea": 80, "Cy": 115, "Dee": -195], "after the adjustment")
    expectDealer(app, "Alex", "after the adjustment")

    // Hand 6: Dee wins on Alex's discard, 50 points.
    recordDiscard(app, winner: "Dee", thrower: "Alex", points: 50)
    expectScores(app, ["Alex": -100, "Bea": 30, "Cy": 65, "Dee": 5], "after hand 6")
    expectDealer(app, "Bea", "after hand 6")
    attach("game-scoreboard-light")

    // Edit hand 1 from 25 to 30 points: Alex +20, Bea -10, Cy -5, Dee -5.
    tapID(app, "log.row.1")
    let editSave = el(app, "record.save")
    XCTAssertTrue(editSave.waitForExistence(timeout: 10))
    XCTAssertTrue(editSave.isEnabled, "Editing opens with the saved hand filled in")
    tapID(app, "record.points.30")
    tapID(app, "record.save")
    waitForSheetToClose(app, "record.save")
    expectScores(app, ["Alex": -80, "Bea": 20, "Cy": 60, "Dee": 0], "after editing hand 1")

    // Undo the last hand (hand 6): the dealer goes back to Alex.
    menu(app, id: "menu.undo", label: "Undo last")
    expectScores(app, ["Alex": 20, "Bea": 70, "Cy": 110, "Dee": -200], "after undo")
    expectDealer(app, "Alex", "after undo")

    // Leave the app and relaunch WITHOUT the reset flag: the game night must still be there.
    XCUIDevice.shared.press(.home)
    Thread.sleep(forTimeInterval: 1.5)
    app.terminate()
    let relaunched = launch(dark: false, reset: false)
    tapID(relaunched, "game.resume")
    XCTAssertTrue(el(relaunched, "score.Alex").waitForExistence(timeout: 10), "Session lost after relaunch")
    expectScores(relaunched, ["Alex": 20, "Bea": 70, "Cy": 110, "Dee": -200], "after relaunch")
    expectDealer(relaunched, "Alex", "after relaunch")

    // End the game night and check the settle-up lines (1 cent per point).
    endGameNight(relaunched)
    let firstLine = el(relaunched, "settle.line.0")
    XCTAssertTrue(firstLine.waitForExistence(timeout: 10), "Settle-up lines")
    let predicate = NSPredicate(format: "identifier BEGINSWITH 'settle.line.'")
    let lines = relaunched.descendants(matching: .any).matching(predicate).allElementsBoundByIndex
      .map(\.label)
    XCTAssertEqual(
      Set(lines),
      ["Dee pays Cy $1.10", "Dee pays Bea $0.70", "Dee pays Alex $0.20"],
      "Settle-up lines")
    XCTAssertTrue(el(relaunched, "standing.Cy").exists)
    attach("game-summary-light")

    // Back home: the finished night is in Recent, and the roster is on Players & stats.
    tapID(relaunched, "summary.done")
    XCTAssertTrue(el(relaunched, "game.players").waitForExistence(timeout: 10))
    attach("game-home-after-light")
    tapID(relaunched, "game.players")
    XCTAssertTrue(el(relaunched, "players.row.Cy").waitForExistence(timeout: 10))
    attach("game-players-light")
    tapID(relaunched, "players.row.Cy")
    XCTAssertTrue(relaunched.navigationBars["Cy"].waitForExistence(timeout: 10))
    attach("game-player-stats-light")
  }

  func testGameNightScreensDark() {
    let app = launch(dark: true)
    XCTAssertTrue(el(app, "game.start").waitForExistence(timeout: 10))
    attach("game-home-dark")
    createPlayersAndStart(app, money: true, scheme: "dark")
    attach("game-scoreboard-empty-dark")

    recordDiscard(app, winner: "Alex", thrower: "Bea", points: 25)
    recordSelfPick(app, winner: "Cy", points: 30)
    expectScores(app, ["Alex": 40, "Bea": -110, "Cy": 155, "Dee": -85], "dark scores")

    tapID(app, "score.record")
    tapID(app, "record.winner.Dee")
    tapID(app, "record.how.discard")
    tapID(app, "record.thrower.Cy")
    tapID(app, "record.points.40")
    attach("game-record-dark")
    app.swipeUp()
    attach("game-record-preview-dark")
    tapID(app, "record.cancel")
    waitForSheetToClose(app, "record.save")
    attach("game-scoreboard-dark")

    endGameNight(app)
    attach("game-summary-dark")
    tapID(app, "summary.done")
    XCTAssertTrue(el(app, "game.players").waitForExistence(timeout: 10))
    attach("game-home-after-dark")
    tapID(app, "game.players")
    XCTAssertTrue(el(app, "players.row.Cy").waitForExistence(timeout: 10))
    attach("game-players-dark")
  }
}
