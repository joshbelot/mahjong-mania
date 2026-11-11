import MahjongCore
import XCTest

@testable import CardScanKit

final class CorpusTests: XCTestCase {
  func testCorpusShapeMatchesTheSpec() {
    let pages = CorpusBuilder.buildPages()
    XCTAssertEqual(pages.count, 30)
    let dev = pages.filter { $0.split == .dev }
    let held = pages.filter { $0.split == .heldOut }
    XCTAssertEqual(dev.count, 20)
    XCTAssertEqual(held.count, 10)
    func rows(_ p: [PageSpec]) -> [RowSpec] { p.flatMap { $0.sections.flatMap(\.rows) } }
    XCTAssertGreaterThanOrEqual(rows(pages).count, 120)
    XCTAssertGreaterThanOrEqual(rows(pages).filter { $0.ambiguity != nil }.count, 20)
    let heldRows = rows(held)
    XCTAssertGreaterThanOrEqual(heldRows.filter { $0.ambiguity == nil }.count, 30)
    XCTAssertGreaterThanOrEqual(heldRows.filter { $0.ambiguity != nil }.count, 8)
    for format in SourceFormat.allCases {
      XCTAssertGreaterThanOrEqual(dev.filter { $0.format == format }.count, 2, "\(format) in dev")
      XCTAssertGreaterThanOrEqual(held.filter { $0.format == format }.count, 1, "\(format) in held-out")
    }
  }

  func testSplitsShareNeitherLayoutsNorHands() {
    let pages = CorpusBuilder.buildPages()
    let devLayouts = Set(pages.filter { $0.split == .dev }.map(\.layout))
    let heldLayouts = Set(pages.filter { $0.split == .heldOut }.map(\.layout))
    XCTAssertTrue(devLayouts.isDisjoint(with: heldLayouts))
    var keys: [Split: Set<String>] = [.dev: [], .heldOut: []]
    var seen = Set<String>()
    for page in pages {
      for row in page.sections.flatMap(\.rows) {
        let key = ScanSemantics.key(row.hand.line)
        XCTAssertTrue(seen.insert(key).inserted, "hand reused: \(row.id)")
        keys[page.split]!.insert(key)
      }
    }
    XCTAssertTrue(keys[.dev]!.isDisjoint(with: keys[.heldOut]!))
  }

  func testGenerationIsDeterministic() {
    let a = CorpusBuilder.buildPages().flatMap { $0.sections.flatMap(\.rows) }.map { $0.hand.source }
    let b = CorpusBuilder.buildPages().flatMap { $0.sections.flatMap(\.rows) }.map { $0.hand.source }
    XCTAssertEqual(a, b)
  }

  func testEveryGeneratedHandParsesAndSectionShiftMatchesTheTruth() {
    for page in CorpusBuilder.buildPages() {
      for section in page.sections {
        for row in section.rows {
          XCTAssertTrue(Notation.serialize(row.hand.line).contains(";"))
          if section.sectionShift != nil { XCTAssertEqual(row.hand.line.shift, .consecutive) }
          if row.marker == "*" { XCTAssertEqual(row.hand.line.shift, .consecutive) }
          if row.marker == "**" { XCTAssertEqual(row.hand.line.shift, .parity) }
        }
      }
    }
  }
}
