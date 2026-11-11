import Foundation
import MahjongCore

public struct FormatReport: Codable {
  public var format: String
  public var pages: Int
  public var tally: ScanTally
  public var seconds: [Double]
  public var rssMB: [Double]
  public var errors: Int
}

public struct SplitReport: Codable {
  public var split: String
  public var overall: ScanTally
  public var byFormat: [FormatReport]
  public var seconds: [Double]
  public var rssMB: [Double]
  public var pageQuality: [String: [String]]  // page id -> problems (clean sources)
}

public struct PoorReport: Codable {
  public var split: String
  public var cleanTotal: Int
  public var cleanAccepted: Int
  public var cleanRejected: [String: [String]]
  public var poorTotal: Int
  public var poorRejected: Int
  public var byKind: [String: [Int]]  // kind -> [rejected, total]
  public var missed: [String]
}

public enum Evaluation {
  /// Runs the recogniser for one file in a child process so peak memory is per source.
  public static func recognizeInChild(_ file: URL, executable: URL) -> PipelineResult? {
    let process = Process()
    process.executableURL = executable
    process.arguments = ["recognize", file.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return try? JSONDecoder().decode(PipelineResult.self, from: data)
  }

  public static func loadManifest(_ root: URL) throws -> Manifest {
    try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
  }

  public static func truthRows(_ page: ManifestPage) -> [ScanTruthRow] {
    page.rows.compactMap { row in
      guard case .success(let line) = Notation.parseLine(row.line) else { return nil }
      return ScanTruthRow(id: row.id, kind: row.kind, line: line)
    }
  }

  public static func runSplit(
    _ split: Split, root: URL, executable: URL, log: (String) -> Void = { _ in }
  ) throws -> (SplitReport, [String: PipelineResult]) {
    let manifest = try loadManifest(root)
    var results: [String: PipelineResult] = [:]
    var byFormat: [SourceFormat: FormatReport] = [:]
    var overall = ScanTally()
    var seconds: [Double] = []
    var rss: [Double] = []
    var quality: [String: [String]] = [:]
    for page in manifest.pages where page.split == split {
      guard let result = recognizeInChild(root.appendingPathComponent(page.file), executable: executable) else {
        log("\(page.id): recogniser crashed")
        var report = byFormat[page.format] ?? FormatReport(format: page.format.rawValue, pages: 0, tally: ScanTally(), seconds: [], rssMB: [], errors: 0)
        report.errors += 1
        // A crash leaves every row omitted (honest failure).
        let t = ScanEvaluator.evaluate(truth: truthRows(page), candidates: []).tally
        report.tally.add(t); report.pages += 1
        byFormat[page.format] = report
        overall.add(t)
        continue
      }
      results[page.id] = result
      let evaluation = ScanEvaluator.evaluate(truth: truthRows(page), candidates: result.candidates)
      var report = byFormat[page.format] ?? FormatReport(format: page.format.rawValue, pages: 0, tally: ScanTally(), seconds: [], rssMB: [], errors: 0)
      report.tally.add(evaluation.tally)
      report.pages += 1
      report.seconds.append(result.seconds)
      report.rssMB.append(Double(result.maxRSSBytes) / 1_048_576)
      byFormat[page.format] = report
      overall.add(evaluation.tally)
      seconds.append(result.seconds)
      rss.append(Double(result.maxRSSBytes) / 1_048_576)
      quality[page.id] = result.pages.flatMap { $0.problems.map(\.rawValue) }
      log("\(page.id) \(page.format.rawValue) \(page.layout): exact \(evaluation.tally.exactDrafts)/\(evaluation.tally.readableRows) ready-wrong \(evaluation.tally.readyButWrongTotal) amb-ready \(evaluation.tally.ambiguousReady) \(String(format: "%.1fs %.0fMB", result.seconds, Double(result.maxRSSBytes) / 1_048_576))")
    }
    let reports = SourceFormat.allCases.compactMap { byFormat[$0] }
    return (SplitReport(split: split.rawValue, overall: overall, byFormat: reports, seconds: seconds, rssMB: rss, pageQuality: quality), results)
  }

  public static func runQuality(
    _ split: Split, root: URL, executable: URL, log: (String) -> Void = { _ in }
  ) throws -> PoorReport {
    let manifest = try loadManifest(root)
    var cleanTotal = 0, cleanAccepted = 0
    var cleanRejected: [String: [String]] = [:]
    for page in manifest.pages where page.split == split {
      guard let r = recognizeInChild(root.appendingPathComponent(page.file), executable: executable) else { continue }
      cleanTotal += 1
      let problems = r.pages.flatMap { $0.problems.map(\.rawValue) }
      if let m = r.pages.first?.metrics { log("clean \(page.id) \(page.format.rawValue) \(problems) sharp \(String(format: "%.3f", m.sharpness)) p90 \(String(format: "%.2f", m.paperBrightness)) clip \(String(format: "%.3f", m.clippedFraction)) edge \(String(format: "%.2f", m.paperEdge)) edgeWords \(m.edgeWords) wordPx \(String(format: "%.1f", m.medianWordPx)) tiles \(m.tileWords)") }
      if problems.isEmpty { cleanAccepted += 1 } else { cleanRejected[page.id] = problems }
    }
    var byKind: [String: [Int]] = [:]
    var missed: [String] = []
    var poorTotal = 0, poorRejected = 0
    for poor in manifest.poorSources where poor.split == split {
      poorTotal += 1
      var rejected = false
      if let r = recognizeInChild(root.appendingPathComponent(poor.file), executable: executable) {
        rejected = !r.pages.flatMap(\.problems).isEmpty || r.pages.isEmpty
        let metrics = r.pages.first?.metrics
        log("\(poor.id): \(r.pages.flatMap { $0.problems.map(\.rawValue) }) sharp \(String(format: "%.3f", metrics?.sharpness ?? 0)) p90 \(String(format: "%.2f", metrics?.paperBrightness ?? 0)) clip \(String(format: "%.3f", metrics?.clippedFraction ?? 0)) edge \(String(format: "%.2f", metrics?.paperEdge ?? 0)) edgeWords \(metrics?.edgeWords ?? 0) wordPx \(String(format: "%.1f", metrics?.medianWordPx ?? 0)) tiles \(metrics?.tileWords ?? 0)")
      } else { rejected = true }
      if rejected { poorRejected += 1 } else { missed.append(poor.id) }
      var k = byKind[poor.kind.rawValue] ?? [0, 0]
      k[1] += 1
      if rejected { k[0] += 1 }
      byKind[poor.kind.rawValue] = k
    }
    return PoorReport(split: split.rawValue, cleanTotal: cleanTotal, cleanAccepted: cleanAccepted, cleanRejected: cleanRejected, poorTotal: poorTotal, poorRejected: poorRejected, byKind: byKind, missed: missed)
  }

  // MARK: Printing

  public static func percent(_ a: Int, _ b: Int) -> String {
    b == 0 ? "n/a" : String(format: "%.1f%%", 100 * Double(a) / Double(b))
  }

  public static func table(_ report: SplitReport) -> String {
    var out = "| Format | Pages | Readable rows | Exact (any state) | Exact and ready | Needs correction | Omitted | Ready but wrong | Ambiguous rows | Correctly flagged or rejected | Ambiguous shown as ready | Median s/page | Peak MB |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
    func line(_ name: String, _ pages: Int, _ t: ScanTally, _ secs: [Double], _ mb: [Double]) -> String {
      let med = secs.sorted().isEmpty ? 0 : secs.sorted()[secs.count / 2]
      let peak = mb.max() ?? 0
      return "| \(name) | \(pages) | \(t.readableRows) | \(t.exactDrafts) (\(percent(t.exactDrafts, t.readableRows))) | \(t.exactReady) (\(percent(t.exactReady, t.readableRows))) | \(t.needsCorrection) | \(t.omitted) | \(t.readyButWrongTotal) | \(t.ambiguousRows) | \(t.ambiguousFlagged + t.ambiguousRejected) | \(t.ambiguousReady) | \(String(format: "%.1f", med)) | \(String(format: "%.0f", peak)) |\n"
    }
    for f in report.byFormat { out += line(f.format, f.pages, f.tally, f.seconds, f.rssMB) }
    out += line("**All**", report.byFormat.reduce(0) { $0 + $1.pages }, report.overall, report.seconds, report.rssMB)
    return out
  }
}
