import XCTest

/// Phase 29 (SPEC §19.2, §19.3): the Tiles cheat sheet, commit-on-tap, Today's Deal on the path and the
/// Speed Round rack.
@MainActor
final class PracticePolishTests: PracticeUITestCase {
  func testCheatSheetOpensMidLessonAndTheLessonContinues() {
    let app = launch(practiceFlags)
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10))
    let prompt = element(app, "lesson.prompt").label
    tap(app, "tiles.button")
    XCTAssertTrue(element(app, "cheat.sheet").waitForExistence(timeout: 5), "No cheat sheet")
    XCTAssertTrue(element(app, "cheat.row.Cracks").waitForExistence(timeout: 5))
    attach("cheat-sheet-in-lesson")
    tap(app, "cheat.done")
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 5))
    XCTAssertEqual(element(app, "lesson.prompt").label, prompt, "Opening the sheet changed the question")
    answer(app, correct: true)
    XCTAssertEqual(element(app, "lesson.combo").exists, false)
  }

  func testCheatSheetIsOnTheIntroThePracticeHeaderAndLearn() {
    let app = launch(practiceFlags)
    XCTAssertTrue(element(app, "tiles.button").waitForExistence(timeout: 10), "No Tiles button in the Practice header")
    tap(app, "path.node.u1l1")
    tap(app, "tiles.button")
    XCTAssertTrue(element(app, "cheat.sheet").waitForExistence(timeout: 5), "No Tiles button on Unit 1's intro")
    tap(app, "cheat.done")
    tap(app, "lesson.close")
    app.tabBars.buttons["Learn"].tap()
    tap(app, "learn.tiles.cheat")
    XCTAssertTrue(element(app, "cheat.sheet").waitForExistence(timeout: 5), "No cheat sheet from Learn")
  }

  func testSingleChoiceCommitsOnTap() {
    let app = launch(practiceFlags)
    tap(app, "path.node.u1l1")
    tap(app, "lesson.start")
    let target = choice(app, correct: true)
    XCTAssertTrue(target.waitForExistence(timeout: 10))
    XCTAssertFalse(element(app, "lesson.check").exists, "A single choice should not need Check")
    target.tap()
    XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 5), "The tap did not commit")
  }

  func testTodaysDealIsOnThePathAndStartsWithOneTap() {
    let app = launch(practiceFlags)
    let card = element(app, "daily.card")
    XCTAssertTrue(card.waitForExistence(timeout: 10), "No Today's Deal node")
    XCTAssertEqual(card.value as? String, "Not played yet. Difficulty 1 of 3.", "2026-11-02 is a Monday")
    attach("todays-deal-node")
    card.tap()
    XCTAssertTrue(element(app, "lesson.prompt").waitForExistence(timeout: 10))
    // The cheat sheet is hidden in the scored Daily Deal.
    XCTAssertFalse(element(app, "tiles.button").isHittable, "The cheat sheet must be hidden in the scored deal")
  }

  func testSpeedRoundShowsThirteenTiles() {
    let app = launch(
      ["-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", "regular", "-UITestPracticeSeed", "3",
       "-UITestToday", "2026-11-02", "-UITestSpeedNoTimer"])
    tap(app, "practice.free.speed")
    tap(app, "speed.start")
    XCTAssertTrue(element(app, "speed.rack").waitForExistence(timeout: 10))
    XCTAssertTrue(element(app, "speed.rack.12").exists, "The rack should show 13 tiles")
    XCTAssertFalse(element(app, "speed.rack.13").exists)
    attach("speed-rack")
    XCTAssertEqual(
      app.descendants(matching: .any).matching(NSPredicate(format: "value == 'being judged'")).count, 1,
      "One tile is lifted")
  }
}
