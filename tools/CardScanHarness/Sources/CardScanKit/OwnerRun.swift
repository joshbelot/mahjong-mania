import Foundation
import MahjongCore

/// Runs private owner samples against the owner's answer key and prints aggregate counts only.
/// Nothing printed or returned here contains card contents: no row text, no per-row result.
public enum OwnerRun {
  public static func run(args: [String], executable: URL) throws {
    func value(_ flag: String) -> String? { args.drop(while: { $0 != flag }).dropFirst().first }
    guard let keyPath = value("--key") else { print("need --key"); return }
    let keyText = try String(contentsOfFile: keyPath, encoding: .utf8)
    let parsed = Notation.parseCardFile(keyText)
    let truth = parsed.lines.enumerated().map { ScanTruthRow(id: "k\($0.offset)", kind: .readable, line: $0.element) }
    print("key: \(truth.count) hands, \(parsed.errors.count) parse errors")
    var total = ScanTally()
    var covered = Set<String>()
    var reasons: [String: Int] = [:]
    var states: [String: [String: Int]] = [:]
    func c0(_ r: PipelineResult) -> String { "none" }
    var files: [URL] = []
    for dir in [value("--photos"), value("--web")].compactMap({ $0 }) {
      let list = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil)) ?? []
      files += list.filter { ["jpg", "jpeg", "png", "avif", "heic", "pdf"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    let webDir = value("--web")
    var perSource: [(kind: String, size: String, quality: [String], cands: Int, ready: Int, exact: Int, wrongReady: Int, secs: Double, mb: Double, tally: ScanTally)] = []
    for file in files {
      guard let r = Evaluation.recognizeInChild(file, executable: executable) else { print("crash on a source"); continue }
      let isWeb = webDir != nil && file.path.hasPrefix(webDir!)
      let evaluation = ScanEvaluator.evaluate(truth: truth, candidates: r.candidates)
      let t = evaluation.tally
      if !isWeb { for (id, o) in evaluation.outcomes where o == .exactReady || o == .exactFlagged { covered.insert(id) } }
      perSource.append((isWeb ? "web" : "phone", file.pathExtension.lowercased(), r.pages.flatMap { $0.problems.map(\.rawValue) }, r.candidates.count, r.candidates.filter { $0.state == .ready }.count, t.exactDrafts, t.readyButWrongTotal, r.seconds, Double(r.maxRSSBytes) / 1_048_576, t))
      if !isWeb { total.add(t) }
      for c in r.candidates { for reason in c.reasons { reasons[reason.replacingOccurrences(of: "\\(\\d+ characters\\)", with: "(n characters)", options: .regularExpression), default: 0] += 1 } }
      states[isWeb ? "web" : "phone", default: [:]][c0(r), default: 0] += 0
      for c in r.candidates { states[isWeb ? "web" : "phone", default: [:]][c.state.rawValue, default: 0] += 1 }
    }
    for (kind, group) in Dictionary(grouping: perSource, by: { $0.kind }).sorted(by: { $0.key < $1.key }) {
      print("== \(kind): \(group.count) sources")
      for s in group {
        print("  \(s.size) quality=\(s.quality.isEmpty ? "accepted" : s.quality.joined(separator: "+")) candidates=\(s.cands) ready=\(s.ready) exact-of-key=\(s.exact)/\(truth.count) ready-but-wrong=\(s.wrongReady) \(String(format: "%.1fs %.0fMB", s.secs, s.mb))")
      }
    }
    print("candidate states (aggregate): \(states)")
    for (reason, n) in reasons.sorted(by: { $0.value > $1.value }).prefix(12) { print("  reason x\(n): \(reason)") }
    print("key hands drafted exactly by at least one phone photo: \(covered.count)/\(truth.count)")
    print("phone photos, summed over sources: exact \(total.exactDrafts) (ready \(total.exactReady)), ready-but-wrong \(total.readyButWrongTotal) (incl. \(total.spuriousReady) spurious)")
  }
}
