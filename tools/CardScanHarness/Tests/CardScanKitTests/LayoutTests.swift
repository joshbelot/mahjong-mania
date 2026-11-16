import CoreGraphics
import MahjongCore
import XCTest

@testable import CardScanKit

final class LayoutTests: XCTestCase {
  private let size = CGSize(width: 2000, height: 1000)

  private func word(_ text: String, x: Double, y: Double, w: Double = 60) -> RawWord {
    RawWord(
      text: text, rect: ScanRect(x: x / 2000, y: y / 1000, width: w / 2000, height: 20 / 1000),
      confidence: 1, exact: true)
  }

  private func rows(_ words: [RawWord]) -> [ScanRow] {
    let inks = [ScanInk](repeating: .neutral, count: words.count)
    return LayoutAnalyzer.analyze(words: words, inks: inks, page: 0, imageSize: size).rows.map(\.row)
  }

  func testTwoColumnsWithTrailingTailsBecomeTwoRows() {
    let words = [
      word("NNNN", x: 100, y: 100), word("EEE", x: 180, y: 100), word("WWW", x: 250, y: 100),
      word("SSSS", x: 320, y: 100), word("25", x: 800, y: 100, w: 30), word("X", x: 850, y: 100, w: 20),
      word("FF", x: 1100, y: 100), word("RRR", x: 1170, y: 100), word("GGG", x: 1250, y: 100),
      word("000", x: 1330, y: 100), word("NNN", x: 1410, y: 100), word("30", x: 1800, y: 100, w: 30),
      word("C", x: 1850, y: 100, w: 20),
    ]
    let found = rows(words)
    XCTAssertEqual(found.count, 2)
    XCTAssertEqual(found.first?.tokens.map(\.text).last, "X")
    XCTAssertEqual(found.last?.tokens.map(\.text).first, "FF")
  }

  func testLeadingTailsAreAttachedToThePatternOnTheirRight() {
    let words = [
      word("25", x: 100, y: 100, w: 30), word("X", x: 150, y: 100, w: 20),
      word("NNNN", x: 300, y: 100), word("EEE", x: 380, y: 100), word("WWW", x: 450, y: 100),
      word("SSSS", x: 520, y: 100),
      word("50", x: 100, y: 200, w: 30), word("C", x: 150, y: 200, w: 20),
      word("FF", x: 300, y: 200), word("RRR", x: 360, y: 200), word("GGG", x: 430, y: 200),
      word("000", x: 500, y: 200), word("SSS", x: 570, y: 200),
    ]
    let found = rows(words)
    XCTAssertEqual(found.count, 2)
    XCTAssertTrue(found.allSatisfy { $0.tokens.count >= 6 })
  }

  func testFootnoteMarkerAndSectionTitleReachTheRow() {
    let words = [
      word("CONSECUTIVE", x: 100, y: 50, w: 140), word("RUN", x: 250, y: 50, w: 50),
      word("NNNN", x: 100, y: 100), word("EEE", x: 180, y: 100), word("WWW", x: 250, y: 100),
      word("SSSS*", x: 320, y: 100), word("X", x: 500, y: 100, w: 20), word("25", x: 540, y: 100, w: 30),
      word("*", x: 100, y: 800, w: 10), word("Numbers", x: 120, y: 800), word("may", x: 200, y: 800, w: 40),
      word("be", x: 250, y: 800, w: 30), word("consecutive", x: 290, y: 800, w: 120),
    ]
    let reading = LayoutAnalyzer.analyze(
      words: words, inks: [ScanInk](repeating: .neutral, count: words.count), page: 0, imageSize: size)
    XCTAssertEqual(reading.rows.count, 1)
    XCTAssertEqual(reading.footnotes["*"], .consecutive)
    XCTAssertEqual(reading.rows.first?.context.sectionTitle, "CONSECUTIVE RUN")
  }

  func testInkClassifierSeparatesColoursFromBlackUnderAWarmCast() {
    // A warm-tinted page: black ink looks brown, red and blue stay distinguishable from it.
    let w = 400, h = 100
    let ctx = Imaging.bitmap(width: w, height: h)
    ctx.setFillColor(rgb(0.9, 0.86, 0.78))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let colours: [CGColor] = [rgb(0.35, 0.28, 0.22), rgb(0.85, 0.2, 0.15), rgb(0.35, 0.4, 0.8), rgb(0.35, 0.28, 0.22)]
    for (i, colour) in colours.enumerated() {
      ctx.setFillColor(colour)
      // Strokes with paper between them, like the inside of a word box.
      for bar in 0..<6 { ctx.fill(CGRect(x: 22 + i * 90 + bar * 12, y: 30, width: 6, height: 40)) }
    }
    let image = ctx.makeImage()!
    let words = (0..<4).map { i in
      RawWord(text: "2222", rect: ScanRect(x: Double(20 + i * 90) / 400, y: 0.3, width: 70.0 / 400, height: 0.4), confidence: 1)
    }
    let inks = InkAnalyzer.classify(words, image: image)
    XCTAssertEqual(inks[0], .neutral)
    XCTAssertEqual(inks[3], .neutral)
    guard case .colour(let red) = inks[1], case .colour(let blue) = inks[2] else {
      return XCTFail("expected two colours, got \(inks)")
    }
    XCTAssertNotEqual(red, blue)
  }
}
