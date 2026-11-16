import CardScanKit
import Foundation
import MahjongCore

let args = Array(CommandLine.arguments.dropFirst())
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let corpus = cwd.appendingPathComponent("corpus")
let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL

func printJSON<T: Encodable>(_ value: T) {
  let enc = JSONEncoder()
  enc.outputFormatting = [.prettyPrinted, .sortedKeys]
  print(String(data: try! enc.encode(value), encoding: .utf8)!)
}

func splitArg() -> Split { args.contains("held-out") ? .heldOut : .dev }

switch args.first {
case "generate":
  let manifest = try CorpusBuilder.build(into: corpus)
  let rows = manifest.pages.flatMap(\.rows)
  print("pages \(manifest.pages.count) rows \(rows.count) ambiguous \(rows.filter { $0.kind == .ambiguous }.count) poor \(manifest.poorSources.count)")
case "recognize":
  let result = Pipeline.run(url: URL(fileURLWithPath: args[1]))
  let enc = JSONEncoder()
  FileHandle.standardOutput.write(try enc.encode(result))
case "freeze":
  let manifestURL = corpus.appendingPathComponent("manifest.json")
  let manifest = try Evaluation.loadManifest(corpus)
  let reportURL = URL(fileURLWithPath: args[1])
  let dev = try JSONDecoder().decode(SplitReport.self, from: Data(contentsOf: reportURL))
  let freeze = try Freeze.make(manifest: manifest, manifestURL: manifestURL, dev: dev, date: args[2])
  let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
  try enc.encode(freeze).write(to: corpus.appendingPathComponent("freeze.json"))
  print("froze: median budget \(freeze.budgetMedianSecondsPerPage)s max \(freeze.budgetMaxSecondsPerPage)s peak \(freeze.budgetPeakMB)MB")
case "eval":
  if splitArg() == .heldOut {
    let freezeURL = corpus.appendingPathComponent("freeze.json")
    guard let data = try? Data(contentsOf: freezeURL) else { print("no freeze.json: run `cardscan freeze` and commit it first"); exit(2) }
    do { try JSONDecoder().decode(Freeze.self, from: data).verify(manifestURL: corpus.appendingPathComponent("manifest.json")) }
    catch { print("\(error.localizedDescription)"); exit(2) }
    print("freeze verified")
  }
  let (report, results) = try Evaluation.runSplit(splitArg(), root: corpus, executable: exe) { print($0) }
  print(Evaluation.table(report))
  let verdict = ScanGateVerdict(report.overall)
  print("gate: exact \(String(format: "%.1f%%", verdict.exactRate * 100)) (>=60%: \(verdict.exactRatePasses)), ambiguous never ready: \(verdict.ambiguousAllFlagged), zero ready-but-wrong: \(verdict.zeroReadyButWrong)")
  _ = results
  if let data = try? Data(contentsOf: corpus.appendingPathComponent("freeze.json")), let f = try? JSONDecoder().decode(Freeze.self, from: data) {
    let secs = report.seconds.sorted()
    let med = secs.isEmpty ? 0 : secs[secs.count / 2]
    print(String(format: "budgets: median %.1fs (budget %.0fs) %@, max %.1fs (budget %.0fs) %@, peak %.0fMB (budget %.0fMB) %@",
      med, f.budgetMedianSecondsPerPage, med <= f.budgetMedianSecondsPerPage ? "OK" : "OVER",
      secs.last ?? 0, f.budgetMaxSecondsPerPage, (secs.last ?? 0) <= f.budgetMaxSecondsPerPage ? "OK" : "OVER",
      report.rssMB.max() ?? 0, f.budgetPeakMB, (report.rssMB.max() ?? 0) <= f.budgetPeakMB ? "OK" : "OVER"))
  }
  if let out = args.drop(while: { $0 != "--json" }).dropFirst().first {
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try enc.encode(report).write(to: URL(fileURLWithPath: out))
  }
case "quality":
  let report = try Evaluation.runQuality(splitArg(), root: corpus, executable: exe) { print($0) }
  printJSON(report)
case "debug":
  let manifest = try Evaluation.loadManifest(corpus)
  guard let page = manifest.pages.first(where: { $0.id == args[1] }) else { break }
  let r = Pipeline.run(url: corpus.appendingPathComponent(page.file))
  let truth = Evaluation.truthRows(page)
  let ev = ScanEvaluator.evaluate(truth: truth, candidates: r.candidates)
  print("page", page.id, page.format.rawValue, page.layout, "problems", r.pages.map { $0.problems.map(\.rawValue) }, "straightened", r.pages.first?.straightened ?? false)
  for t in truth { print("TRUTH", t.id, t.kind.rawValue, ev.outcomes[t.id]!.rawValue, Notation.serialize(t.line)) }
  for c in r.candidates { print("CAND", c.state.rawValue, "|", c.rawText, "|", c.reasons.joined(separator: "; "), "=>", c.line.map { Notation.serialize($0) } ?? "-") }
case "ink":
  let manifest = try Evaluation.loadManifest(corpus)
  guard let page = manifest.pages.first(where: { $0.id == args[1] }) else { break }
  let loaded = try SourceLoader.load(corpus.appendingPathComponent(page.file))[0]
  let img = loaded.image
  let words = loaded.textLayer ?? OCR.recognize(img)
  var lines: [Int: String] = [:]
  InkAnalyzer.trace = { i, d, h, v in lines[i] = String(format: "dist%.3f ang%.0f v%.2f", d, h, v) }
  let inks = InkAnalyzer.classify(words, image: img)
  for (i, w) in words.enumerated() where i < 60 { print(w.text, String(format: "conf%.2f", w.confidence), inks[i], lines[i] ?? "", String(format: "rect %.3f %.3f %.3f %.3f", w.rect.x, w.rect.y, w.rect.width, w.rect.height)) }
case "render":
  let loaded = try SourceLoader.load(URL(fileURLWithPath: args[1]))[0]
  Imaging.write(loaded.image, to: URL(fileURLWithPath: args[2]))
case "owner":
  try OwnerRun.run(args: Array(args.dropFirst()), executable: exe)
default:
  print("usage: cardscan generate | recognize <file> | eval <dev|held-out> [--json out] | quality <dev|held-out> | owner --key <file> --photos <dir> [--web <dir>]")
}
