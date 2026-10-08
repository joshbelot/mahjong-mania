import Foundation

extension Notation {
  /// Parses the card file format. Valid lines are kept and invalid ones reported with their 1-based line
  /// number. Line IDs are `L<index>_<fnv1a(source)>` so session records survive re-parsing.
  public static func parseCardFile(_ text: String) -> CardFileParseResult {
    var name: String?
    var year: Int?
    var section = "Hands"
    var lines: [CardLine] = []
    var errors: [CardFileError] = []
    var perSection: [String: Int] = [:]

    let normalised = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalised.split(separator: "\n", omittingEmptySubsequences: false)
    for (offset, rawSubstring) in rawLines.enumerated() {
      let raw = String(rawSubstring)
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      let lineNumber = offset + 1
      if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }

      if trimmed.hasPrefix("!") {
        let rest = String(trimmed.dropFirst())
        if rest == "year" || rest.hasPrefix("year ") || rest.hasPrefix("year\t") {
          let value = rest.dropFirst(4).trimmingCharacters(in: .whitespaces)
          if let parsed = Int(value), (1000...9999).contains(parsed) {
            year = parsed
          } else {
            errors.append(
              CardFileError(
                lineNumber: lineNumber, text: raw,
                errors: [
                  ParseError(
                    code: .badChar, message: "The year must be a 4-digit number, e.g. !year 2026",
                    range: 0..<raw.count)
                ]))
          }
        } else if name == nil {
          let candidate = rest.trimmingCharacters(in: .whitespaces)
          if !candidate.isEmpty { name = candidate }
        }
        continue
      }

      if trimmed.hasPrefix("#") {
        let title = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        section = title.isEmpty ? "Hands" : title
        continue
      }

      let index = (perSection[section] ?? 0) + 1
      switch parseLine(raw, id: nil, section: section, indexInSection: index) {
      case .success(var line):
        line.id = "L\(lines.count)_" + fnv1aBase36(line.source)
        lines.append(line)
        perSection[section] = index
      case .failure(let list):
        errors.append(CardFileError(lineNumber: lineNumber, text: raw, errors: list.errors))
      }
    }

    return CardFileParseResult(name: name, year: year, lines: lines, errors: errors)
  }

  /// Builds a `Card` from a parsed file.
  public static func makeCard(
    from result: CardFileParseResult, id: String, builtIn: Bool = false, fallbackName: String = "Untitled card",
    createdAt: Date, updatedAt: Date? = nil
  ) -> Card {
    Card(
      id: id, name: result.name ?? fallbackName, year: result.year, builtIn: builtIn, lines: result.lines,
      createdAt: createdAt, updatedAt: updatedAt ?? createdAt)
  }
}
