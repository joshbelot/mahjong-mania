import MahjongCore
import XCTest

@testable import CardScanKit

final class PipelineTests: XCTestCase {
  /// A text-layer PDF page read straight from the PDF (no OCR): nothing may be ready-but-wrong, every
  /// ambiguous row must be flagged, and most readable rows must come out exact.
  func testTextLayerPDFEndToEnd() throws {
    let page = try XCTUnwrap(CorpusBuilder.buildPages().first { $0.format == .textPDF })
    let style = Layouts.all[page.layout]!
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan-test-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: url) }
    var options = RenderOptions()
    options.visualAmbiguity = false
    Imaging.writeTextPDF(page, style: style, options: options, to: url)
    let result = Pipeline.run(url: url)
    XCTAssertNil(result.error)
    XCTAssertEqual(result.pages.first?.usedTextLayer, true)
    let truth = page.sections.flatMap(\.rows).compactMap { row -> ScanTruthRow? in
      guard case .success(let line) = Notation.parseLine(row.hand.source) else { return nil }
      return ScanTruthRow(id: row.id, kind: row.ambiguity == nil ? .readable : .ambiguous, line: line)
    }
    let tally = ScanEvaluator.evaluate(truth: truth, candidates: result.candidates).tally
    XCTAssertEqual(tally.readyButWrongTotal, 0)
    XCTAssertEqual(tally.ambiguousReady, 0)
    XCTAssertGreaterThanOrEqual(tally.exactRate, 0.6)
  }

  func testBoundedLoaderRejectsMissingAndTooLargeInput() {
    XCTAssertThrowsError(try SourceLoader.load(URL(fileURLWithPath: "/nonexistent/file.jpg")))
    XCTAssertEqual(SourceLoader.maxPages, 4)
    XCTAssertEqual(SourceLoader.maxPixels, 12_000_000)
  }

  func testQualityMessagesAreSpecific() {
    for problem in QualityProblem.allCases { XCTAssertFalse(problem.message.isEmpty) }
    XCTAssertTrue(QualityProblem.notACard.message.contains("doesn't look like a card"))
  }
}
