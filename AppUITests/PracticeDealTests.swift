import XCTest

/// The Daily Deal, the Speed Round (without the clock), free play and "Review mistakes".
@MainActor
final class PracticeDealTests: PracticeUITestCase {
  private func flags(_ extra: [String] = [], placement: String = "new") -> [String] {
    [
      "-UITestResetData", "-UITestTab", "practice", "-UITestPlacement", placement, "-UITestPracticeSeed", "3",
      "-UITestRevealAnswers", "-UITestToday", "2026-11-02", "-UITestDailyGoal", "casual",
    ] + extra
  }

  // MARK: Daily Deal

  private func playDeal(_ app: XCUIApplication, shots: String?) {
    var opened = false
    for _ in 0..<4 where !opened {
      app.swipeDown()
      let card = element(app, "daily.card")
      XCTAssertTrue(card.waitForExistence(timeout: 10), "No Daily Deal card")
      card.tap()
      opened = element(app, "lesson.prompt").waitForExistence(timeout: 5)
    }
    XCTAssertTrue(opened, "The deal did not open")
    if let shots { attach("\(shots)-1-pick") }
    tap(app, "lesson.choice.0")  // a single choice commits on tap: there is no Check
    XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10))
    if let shots { attach("\(shots)-2-pick-feedback") }
    tap(app, "lesson.continue")
    XCTAssertTrue(element(app, "lesson.tile.0").waitForExistence(timeout: 10), "The pass part did not open")
    if let shots { attach("\(shots)-3-pass") }
    for position in 0..<3 {
      let tile = element(app, "lesson.tile.\(position)")
      if tile.label == "Joker" { continue }
      tile.tap()
    }
    // A joker can't be passed, so pick any three others.
    var next = 3
    while element(app, "lesson.count").label != "Selected 3 of 3" && next < 13 {
      let tile = element(app, "lesson.tile.\(next)")
      if tile.label != "Joker" { tile.tap() }
      next += 1
    }
    tap(app, "lesson.check")
    XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10))
    tap(app, "lesson.continue")
  }

  private func dailyDealTour(dark: Bool = false, textSize: String? = nil, tag: String) {
    let app = launch(flags(), dark: dark, textSize: textSize)
    let card = element(app, "daily.card")
    XCTAssertTrue(card.waitForExistence(timeout: 10))
    attach("daily-\(tag)-0-home")
    playDeal(app, shots: "daily-\(tag)")
    let title = element(app, "deal.title")
    XCTAssertTrue(title.waitForExistence(timeout: 10), "No result screen")
    XCTAssertEqual(title.label, "Daily Deal #305", "2026-11-02 is deal 305")
    let text = element(app, "deal.share.text").label
    XCTAssertTrue(text.hasPrefix("Mahjong Mania Daily #305 🀄\nPick: "), text)
    XCTAssertTrue(text.contains("\nPass: "), text)
    XCTAssertTrue(text.contains("🔥 1-day streak"), text)
    XCTAssertFalse(element(app, "deal.practice").exists, "The first play is the scored one")
    attach("daily-\(tag)-4-result")
    tap(app, "lesson.continue")
    // 50 XP and the first goal: celebrations may follow; get through them.
    while element(app, "celebration.continue").waitForExistence(timeout: 3) { tap(app, "celebration.continue") }
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    XCTAssertTrue(element(app, "deal.played").waitForExistence(timeout: 5), "No \"Played today\"")
    XCTAssertTrue(element(app, "deal.countdown").exists, "No countdown to the next deal")
    attach("daily-\(tag)-5-played")

    // A replay is practice and pays nothing.
    playDeal(app, shots: nil)
    XCTAssertTrue(element(app, "deal.practice").waitForExistence(timeout: 10))
    XCTAssertFalse(element(app, "deal.xp").exists, "A replay must not pay XP")
    attach("daily-\(tag)-6-replay")
    tap(app, "lesson.continue")
  }

  func testDailyDealLight() { dailyDealTour(tag: "light") }
  func testDailyDealDark() { dailyDealTour(dark: true, tag: "dark") }
  func testDailyDealAccessibilitySize() { dailyDealTour(textSize: Self.accessibilityM, tag: "ax") }

  // MARK: Speed Round

  func testSpeedRoundWithoutTheTimer() {
    let app = launch(flags(["-UITestSpeedNoTimer"], placement: "regular"))
    tap(app, "practice.free.speed")
    XCTAssertTrue(element(app, "speed.start").waitForExistence(timeout: 10))
    attach("speed-0-ready")
    tap(app, "speed.start")
    for n in 0..<30 {
      let keep = element(app, "speed.keep")
      let choice = element(app, "speed.choice.0")
      if keep.waitForExistence(timeout: 5) {
        if n == 0 { attach("speed-1-keep-pass") }
        keep.tap()
      } else {
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "No question \(n + 1)")
        if n == 23 { attach("speed-2-bonus") }
        choice.tap()
      }
    }
    let result = element(app, "speed.result")
    XCTAssertTrue(result.waitForExistence(timeout: 10), "No result after 30 questions")
    let right = Int(result.value as? String ?? "") ?? -1
    XCTAssertTrue((0...30).contains(right), "Odd score \(right)")
    attach("speed-3-result")
    tap(app, "speed.done")
    while element(app, "celebration.continue").waitForExistence(timeout: 3) { tap(app, "celebration.continue") }
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    // The best is remembered.
    tap(app, "practice.free.speed")
    XCTAssertEqual(element(app, "speed.best").label, "Your best: \(right)")
  }

  func testSpeedRoundIsLockedUntilUnitSix() {
    let app = launch(flags())
    let row = element(app, "practice.free.speed")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertFalse(row.isEnabled, "Speed Round should be locked for a new player")
    app.swipeUp()
    attach("speed-locked")
  }

  // MARK: Free play

  private func freePlayTour(id: String, dark: Bool, textSize: String?, tag: String) {
    let app = launch(flags(), dark: dark, textSize: textSize)
    app.swipeUp()
    tap(app, "practice.free.\(id)")
    let seed = element(app, "free.seed")
    XCTAssertTrue(seed.waitForExistence(timeout: 10), "Free play did not open")
    XCTAssertEqual(seed.label, "Deal #3", "The first deal should be the forced seed")
    attach("free-\(id)-\(tag)-1")
    if id == "pick" {
      tap(app, "lesson.choice.0")
    } else {
      var picked = 0
      var position = 0
      while picked < 3 && position < 13 {
        let tile = element(app, "lesson.tile.\(position)")
        if tile.exists && tile.label != "Joker" { tile.tap(); picked += 1 }
        position += 1
      }
    }
    tap(app, "lesson.check")
    XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10), "No feedback")
    attach("free-\(id)-\(tag)-2-feedback")
    // Try again replays the same deal.
    tap(app, "lesson.secondary")
    XCTAssertEqual(element(app, "free.seed").label, "Deal #3", "Try again changed the deal")
    XCTAssertTrue(element(app, "lesson.check").waitForExistence(timeout: 5))
    // Answer again and go to the next deal.
    if id == "pick" {
      tap(app, "lesson.choice.1")
    } else {
      var picked = 0
      var position = 0
      while picked < 3 && position < 13 {
        let tile = element(app, "lesson.tile.\(position)")
        if tile.exists && tile.label != "Joker" { tile.tap(); picked += 1 }
        position += 1
      }
    }
    tap(app, "lesson.check")
    XCTAssertTrue(element(app, "lesson.feedback").waitForExistence(timeout: 10))
    tap(app, "lesson.continue")
    XCTAssertNotEqual(element(app, "free.seed").label, "Deal #3", "Next deal kept the same deal")
  }

  func testPickAHandFreePlayLight() { freePlayTour(id: "pick", dark: false, textSize: nil, tag: "light") }
  func testPickAHandFreePlayDark() { freePlayTour(id: "pick", dark: true, textSize: nil, tag: "dark") }
  func testCharlestonFreePlayLight() { freePlayTour(id: "charleston", dark: false, textSize: nil, tag: "light") }
  func testCharlestonFreePlayAccessibilitySize() {
    freePlayTour(id: "charleston", dark: false, textSize: Self.accessibilityM, tag: "ax")
  }

  // MARK: Review mistakes

  func testReviewMistakesPlaysTheQueuedQuestions() {
    let app = launch(flags(["-UITestReviewItems", "3"]))
    app.swipeUp()
    let row = element(app, "practice.free.review")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    attach("review-0-row")
    row.tap()
    for _ in 0..<3 { answer(app, correct: true) }
    XCTAssertEqual(element(app, "review.score").label, "3 of 3 right")
    attach("review-1-result")
    tap(app, "lesson.continue")
    while element(app, "celebration.continue").waitForExistence(timeout: 3) { tap(app, "celebration.continue") }
    XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    // Answered right, they are scheduled for later: nothing is due now.
    app.swipeUp()
    tap(app, "practice.free.review")
    XCTAssertTrue(app.alerts["Nothing to review"].waitForExistence(timeout: 5))
  }
}
