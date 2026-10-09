import Foundation
import MahjongCore

/// Which section the edited line goes in.
enum SectionChoice: Hashable, Sendable {
  case existing(String)
  case new
}

/// One problem shown under the notation field.
struct EditorProblem: Hashable, Sendable {
  var message: String
  /// Character range inside the notation text, or nil when the problem is not about the notation itself.
  var range: Range<Int>?
}

/// What the live area of the line editor shows.
enum EditorStatus: Equatable, Sendable {
  /// Nothing typed yet; the text is a hint, not an error.
  case empty(String)
  case invalid([EditorProblem])
  case valid(CardLine)
}

/// A key of the quick-insert row.
enum EditorKey: Hashable, Sendable {
  case text(String)
  case space
  case backspace
}

/// Pure state behind the line editor: the fields, the text that `Notation.parseLine` reads, and the
/// resulting status. Kept free of SwiftUI so it can be unit-tested.
struct LineEditorModel: Equatable, Sendable {
  static let defaultSectionName = "Hands"
  static let quickPoints = [25, 30, 35, 40, 45, 50, 75]
  static let pointsRange = 1...500

  /// The insert keys, in the order of SPEC §11.7: `F N E W S R G 0 D 1–9 /x /y /z /c /b /d | + =`.
  static let tileKeys = ["F", "N", "E", "W", "S", "R", "G", "0", "D"] + (1...9).map(String.init)
  static let suitKeys = ["/x", "/y", "/z", "/c", "/b", "/d"]
  static let operatorKeys = ["|", "+", "="]

  let availableSections: [String]
  var sectionChoice: SectionChoice
  var newSectionName: String
  var name: String
  var notation: String
  var points: Int
  var concealed: Bool
  var shift: Shift

  /// A blank form for a new hand. The last existing section is preselected.
  init(availableSections: [String]) {
    self.availableSections = availableSections
    if let last = availableSections.last {
      sectionChoice = .existing(last)
      newSectionName = ""
    } else {
      sectionChoice = .new
      newSectionName = Self.defaultSectionName
    }
    name = ""
    notation = ""
    points = 25
    concealed = false
    shift = .none
  }

  /// A form filled from an existing line of `card`.
  init(card: Card, editing line: CardLine) {
    availableSections = card.sections
    sectionChoice = .existing(line.section)
    newSectionName = ""
    name = line.name ?? ""
    notation = line.variants.map(\.source).joined(separator: " | ")
    points = line.points
    concealed = line.concealed
    shift = line.shift
  }

  // MARK: Derived text

  /// The notation with line breaks turned into spaces (character offsets stay the same).
  var cleanNotation: String {
    String(notation.map { $0.isNewline ? " " : $0 })
  }

  var cleanName: String {
    String(name.map { $0 == ";" || $0.isNewline ? " " : $0 })
      .trimmingCharacters(in: .whitespaces)
  }

  var effectiveSection: String {
    switch sectionChoice {
    case .existing(let section):
      return section
    case .new:
      let cleaned = String(newSectionName.map { $0.isNewline ? " " : $0 })
        .trimmingCharacters(in: .whitespaces)
      return cleaned
    }
  }

  /// The full line the parser sees: `notation ; points ; X|C [; name] [; shift|shift2]`.
  var composedText: String {
    var text = cleanNotation + " ; \(points) ; " + (concealed ? "C" : "X")
    if !cleanName.isEmpty || shift != .none {
      text += " ; " + cleanName
    }
    switch shift {
    case .none: break
    case .consecutive: text += " ; shift"
    case .parity: text += " ; shift2"
    }
    return text
  }

  // MARK: Validation

  var status: EditorStatus {
    let text = cleanNotation
    if text.allSatisfy({ $0.isWhitespace }) {
      return .empty("Type a hand, or use the keys above the keyboard. Example: FF 2026/x 2222/y 6666/y")
    }
    if let semicolon = text.firstIndex(of: ";") {
      let offset = text.distance(from: text.startIndex, to: semicolon)
      return .invalid([
        EditorProblem(
          message: "Leave out the semicolons. Points, X or C and the name have their own fields below.",
          range: offset..<(offset + 1))
      ])
    }
    switch Notation.parseLine(composedText, id: nil, section: sectionForParsing) {
    case .success(let line):
      return .valid(line)
    case .failure(let list):
      let length = text.count
      let problems = list.errors.map { error -> EditorProblem in
        guard error.range.lowerBound <= length else {
          return EditorProblem(message: error.message, range: nil)
        }
        let upper = min(max(error.range.upperBound, error.range.lowerBound), length)
        return EditorProblem(message: error.message, range: error.range.lowerBound..<upper)
      }
      return .invalid(problems)
    }
  }

  private var sectionForParsing: String {
    let section = effectiveSection
    return section.isEmpty ? Self.defaultSectionName : section
  }

  /// Why the section field blocks saving, if it does.
  var sectionProblem: String? {
    if case .new = sectionChoice, effectiveSection.isEmpty { return "Name the new section." }
    return nil
  }

  /// The line to save, when everything is valid.
  var validLine: CardLine? {
    guard sectionProblem == nil, case .valid(let line) = status else { return nil }
    return line
  }

  var canSave: Bool { validLine != nil }

  /// The `^~~` marker line printed under the notation: spaces up to the error, then a caret and tildes.
  static func marker(for range: Range<Int>) -> String {
    let lower = max(range.lowerBound, 0)
    let length = max(range.upperBound - lower, 1)
    return String(repeating: " ", count: lower) + "^" + String(repeating: "~", count: length - 1)
  }

  // MARK: Key row

  /// Applies a key. Text is appended at the end (a plain `TextField` exposes no cursor on iOS 17).
  mutating func press(_ key: EditorKey) {
    switch key {
    case .space:
      notation += " "
    case .backspace:
      if !notation.isEmpty { notation.removeLast() }
    case .text(let token):
      if Self.operatorKeys.contains(token) {
        while notation.last?.isWhitespace == true { notation.removeLast() }
        notation += (notation.isEmpty ? "" : " ") + token + " "
      } else {
        notation += token
      }
    }
  }
}
