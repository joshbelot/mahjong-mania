import Foundation
import MahjongCore

/// Pure helpers that turn card edits into new card-file text (SPEC §9.5). User cards are stored as text, so
/// an edit is: parse the card, change its lines, serialise again. Lines that do not parse are dropped by
/// that round trip, but the app only ever writes valid lines.
enum CardEditing {
  static func text(adding line: CardLine, to card: Card) -> String {
    var copy = card
    copy.lines.append(line)
    return Notation.serialize(copy)
  }

  /// Replaces the line in place (so it keeps its position); appends it if the ID is no longer there.
  static func text(replacing lineID: String, with line: CardLine, in card: Card) -> String {
    var copy = card
    if let index = copy.lines.firstIndex(where: { $0.id == lineID }) {
      copy.lines[index] = line
    } else {
      copy.lines.append(line)
    }
    return Notation.serialize(copy)
  }

  static func text(removing lineID: String, from card: Card) -> String {
    var copy = card
    copy.lines.removeAll { $0.id == lineID }
    return Notation.serialize(copy)
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
