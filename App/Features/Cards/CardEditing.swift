import Foundation
import MahjongCore

/// Pure helpers that turn card edits into new card-file text (SPEC §9.5). User cards are stored as text, so
/// an edit changes only the affected line of that text. Comments (`//`), blank lines, section order and
/// lines that do not parse (for example a half-typed hand pasted in) are left exactly as the user wrote them.
enum CardEditing {
  /// Adds the line at the end of its section, or in a new section at the end of the text.
  static func text(adding line: CardLine, to source: String) -> String {
    var raw = rawLines(of: source)
    insert(Notation.serialize(line), section: line.section, into: &raw)
    return raw.joined(separator: "\n")
  }

  /// Replaces the line in place (so it keeps its position). If its section changed it moves to the end of
  /// the new section; if the ID is no longer there the line is added.
  static func text(replacing lineID: String, with line: CardLine, in source: String) -> String {
    let parsed = Notation.parseCardFile(source)
    var raw = rawLines(of: source)
    guard let index = parsed.lines.firstIndex(where: { $0.id == lineID }),
      let rawIndex = rawIndex(ofParsedLine: index, in: parsed, count: raw.count)
    else {
      insert(Notation.serialize(line), section: line.section, into: &raw)
      return raw.joined(separator: "\n")
    }
    if parsed.lines[index].section == line.section {
      raw[rawIndex] = Notation.serialize(line)
    } else {
      raw.remove(at: rawIndex)
      insert(Notation.serialize(line), section: line.section, into: &raw)
    }
    return raw.joined(separator: "\n")
  }

  static func text(removing lineID: String, from source: String) -> String {
    let parsed = Notation.parseCardFile(source)
    var raw = rawLines(of: source)
    guard let index = parsed.lines.firstIndex(where: { $0.id == lineID }),
      let rawIndex = rawIndex(ofParsedLine: index, in: parsed, count: raw.count)
    else { return source }
    raw.remove(at: rawIndex)
    return raw.joined(separator: "\n")
  }

  // MARK: Text helpers

  private static func rawLines(of source: String) -> [String] {
    source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
  }

  private static func rawIndex(ofParsedLine index: Int, in parsed: CardFileParseResult, count: Int) -> Int? {
    guard parsed.sourceLineNumbers.indices.contains(index) else { return nil }
    let rawIndex = parsed.sourceLineNumbers[index] - 1
    return (0..<count).contains(rawIndex) ? rawIndex : nil
  }

  /// Puts `text` after the last non-blank line of the last block of `section` (a `# Section` header and
  /// everything up to the next header). The lines before the first header belong to the section "Hands".
  /// If the section is not in the text it is added at the end.
  private static func insert(_ text: String, section: String, into raw: inout [String]) {
    var currentName = "Hands"
    var lastIndex = -1
    var target: Int?
    for (index, line) in raw.enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("#") {
        let title = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        if currentName == section { target = lastIndex }
        currentName = title.isEmpty ? "Hands" : title
        lastIndex = index
      } else if !trimmed.isEmpty {
        lastIndex = index
      }
    }
    if currentName == section { target = lastIndex }
    if let target {
      raw.insert(text, at: target + 1)
      return
    }
    while let last = raw.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { raw.removeLast() }
    raw.append(contentsOf: ["# \(section)", text, ""])
  }
}

/// The result of checking pasted card-file text (SPEC §11.7 Import).
struct ImportReport: Equatable {
  var name: String?
  var year: Int?
  var validCount: Int
  var problems: [CardFileError]
  /// Section headers and valid lines only (no `!` header lines), ready to append to an existing card.
  var body: String

  /// "37 hands ✓", or "No hands found".
  var summary: String {
    switch validCount {
    case 0: return "No hands found"
    case 1: return "1 hand \u{2713}"
    default: return "\(validCount) hands \u{2713}"
    }
  }

  var problemSummary: String? {
    switch problems.count {
    case 0: return nil
    case 1: return "1 line has a problem and will be skipped"
    default: return "\(problems.count) lines have problems and will be skipped"
    }
  }

  var importTitle: String {
    switch validCount {
    case 0: return "Import hands"
    case 1: return "Import 1 hand"
    default: return "Import \(validCount) hands"
    }
  }
}

enum CardImport {
  static let fallbackName = "Imported card"

  static func check(_ text: String) -> ImportReport {
    let result = Notation.parseCardFile(text)
    let card = Notation.makeCard(
      from: result, id: "import", fallbackName: fallbackName, createdAt: Date(timeIntervalSince1970: 0))
    let body = Notation.serialize(card)
      .split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.hasPrefix("!") }
      .joined(separator: "\n")
    return ImportReport(
      name: result.name, year: result.year, validCount: result.lines.count, problems: result.errors,
      body: result.lines.isEmpty ? "" : body)
  }

  /// The name to give a new card: what the user typed, else the name in the file, else a fallback.
  static func cardName(typed: String, report: ImportReport) -> String {
    let single = { (value: String) -> String in
      value.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
        .trimmingCharacters(in: .whitespaces)
    }
    let typedName = single(typed)
    if !typedName.isEmpty { return typedName }
    if let fileName = report.name, !single(fileName).isEmpty { return single(fileName) }
    return fallbackName
  }

  /// Card-file text for a brand-new card.
  static func newCardText(name: String, report: ImportReport) -> String {
    var text = "! \(name)\n"
    if let year = report.year { text += "!year \(year)\n" }
    return text + report.body
  }
}
