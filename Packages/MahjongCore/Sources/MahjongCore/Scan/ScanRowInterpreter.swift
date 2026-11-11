import Foundation

/// Tunable thresholds. Frozen from the development set before the held-out run (see CARD_SCAN_EVALUATION).
public struct ScanInterpreterConfig: Hashable, Codable, Sendable {
  /// A row whose weakest token is below this is never "ready".
  public var minimumConfidence: Double
  public init(minimumConfidence: Double = 0.5) { self.minimumConfidence = minimumConfidence }
}

/// Deterministic parsing of one recognised row into a draft hand.
///
/// OCR text and ink are data. Nothing a row says can do anything but become a candidate hand. A row is only
/// `ready` when every field is resolved from the source; every guess (a substituted character, a missing
/// suit colour, a footnote with no explanation) leaves it `needsCheck` with a plain reason.
public enum ScanRowInterpreter {
  private static let tileLetters = Set("FNEWSRGD")
  private static let colourWords: [String: Int] = [
    "red": 101, "green": 102, "blue": 103, "yellow": 104,
  ]

  private enum Piece {
    case tile(text: String, ink: ScanInk, confidence: Double, exact: Bool)
    case op(String)
    case alternative
    case unknown(String, confidence: Double)
  }

  /// Does the row look like a hand at all (as opposed to a title, section header, footnote or legend)?
  public static func looksLikeHand(_ row: ScanRow) -> Bool {
    let tokens = row.tokens.map { clean($0.text) }
    let tileLike = tokens.filter { isTileLike($0) }
    let hasExposure = tokens.contains { exposureForm($0) != nil }
    if tileLike.count >= 2 && hasExposure { return true }
    let digitsOnly = tokens.filter { $0.allSatisfy(\.isNumber) && $0.count <= 3 }
    return tileLike.count >= 3 && !digitsOnly.isEmpty && tokens.count >= 4 && !isFootnote(tokens)
  }

  /// A footnote row: starts with a marker and then explanatory words.
  public static func isFootnote(_ tokens: [String]) -> Bool {
    guard let first = tokens.first else { return false }
    return first.allSatisfy { "*†‡".contains($0) } && tokens.count >= 3
  }

  /// Which shift a footnote text grants. `nil` when the wording is not understood.
  public static func footnoteShift(_ text: String) -> Shift? {
    let lower = text.lowercased()
    if lower.contains("odd") || lower.contains("even") || lower.contains("parity") { return .parity }
    if lower.contains("consec") || lower.contains("like") || lower.contains("any number") {
      return .consecutive
    }
    return nil
  }

  public static func sectionImpliesShift(_ title: String?) -> Bool {
    guard let lower = title?.lowercased() else { return false }
    return lower.contains("like") || lower.contains("consec") || lower.contains("run")
  }

  // MARK: Interpretation

  public static func interpret(
    _ row: ScanRow, context: ScanPageContext = ScanPageContext(),
    config: ScanInterpreterConfig = ScanInterpreterConfig()
  ) -> ScanCandidate {
    var reasons: [String] = []
    var tokens = attachColourWords(row.tokens)

    // 1. Parenthesised notes and leader dots.
    var notes: [String] = []
    var depth = 0
    var body: [ScanToken] = []
    for token in tokens {
      let text = token.text.trimmingCharacters(in: .whitespaces)
      if text.isEmpty || isLeader(text) { continue }
      let opens = text.filter { $0 == "(" }.count
      let closes = text.filter { $0 == ")" }.count
      if depth > 0 || opens > 0 {
        notes.append(text)
        depth = max(0, depth + opens - closes)
        continue
      }
      body.append(token)
    }
    tokens = body

    // 2. Footnote markers.
    var marker: String?
    tokens = tokens.compactMap { token in
      var text = token.text
      var found = ""
      while let last = text.last, "*†‡".contains(last) {
        found.append("*")
        text.removeLast()
      }
      if !found.isEmpty {
        if marker != nil && marker != found { reasons.append("Two different footnote marks") }
        marker = found
      }
      if text.isEmpty { return nil }
      var copy = token
      copy.text = text
      return copy
    }

    // 3. Exposure and points.
    var exposure: Bool?
    var points: Int?
    var pointsConfidence = 1.0
    let exposureIndices = tokens.indices.filter { exposureForm(clean(tokens[$0].text)) != nil }
    var consumed = Set<Int>()
    if exposureIndices.count > 1 {
      reasons.append("More than one X/C mark")
    } else if let e = exposureIndices.first {
      let form = exposureForm(clean(tokens[e].text))!
      exposure = form.concealed
      consumed.insert(e)
      pointsConfidence = tokens[e].confidence
      if let merged = form.points {
        points = merged
      } else {
        let right = e + 1 < tokens.count ? pointsValue(clean(tokens[e + 1].text)) : nil
        let left = e > 0 ? pointsValue(clean(tokens[e - 1].text)) : nil
        if e == tokens.count - 1 || (right == nil && left != nil) {
          if let left { points = left; consumed.insert(e - 1) }
        } else if e == 0 || (left == nil && right != nil) {
          if let right { points = right; consumed.insert(e + 1) }
        } else if let right, let left {
          // Numbers on both sides: the pattern may end in a number. Coloured digits are pattern tiles;
          // two plain numbers cannot be told apart, so ask.
          if case .colour = tokens[e - 1].ink {
            points = right
            consumed.insert(e + 1)
          } else if case .colour = tokens[e + 1].ink {
            points = left
            consumed.insert(e - 1)
          } else {
            points = right
            consumed.insert(e + 1)
            reasons.append("Points could be on either side of X/C")
          }
        }
        if let used = consumed.subtracting([e]).first {
          pointsConfidence = min(pointsConfidence, tokens[used].confidence)
        }
      }
    }
    if exposure == nil { reasons.append("No X or C mark found") }
    if points == nil { reasons.append("No points found") }

    // 4. Pattern tokens: everything left, up to the first lowercase word (an unbracketed note).
    var pieces: [Piece] = []
    var inNote = false
    for index in tokens.indices where !consumed.contains(index) {
      let token = tokens[index]
      let text = clean(token.text)
      if text.isEmpty { continue }
      if isAlternative(text) {
        if !inNote { pieces.append(.alternative) }
        continue
      }
      if inNote { notes.append(text); continue }
      if text == "+" || text == "=" { pieces.append(.op(text)); continue }
      if isTileLike(text) {
        pieces.append(.tile(text: text, ink: token.ink, confidence: token.confidence, exact: token.exactText))
      } else if text.contains(where: \.isLowercase) {
        inNote = true
        notes.append(text)
      } else {
        pieces.append(.unknown(text, confidence: token.confidence))
      }
    }

    // 5. Build variants.
    var variantSources: [String] = []
    var current: [String] = []
    var colourOrder: [Int] = []
    var weakest = min(pointsConfidence, 1.0)
    var maxColoursInVariant = 0
    var sawNumbers = false
    var variantColours = Set<Int>()
    func closeVariant() {
      if !current.isEmpty { variantSources.append(current.joined(separator: " ")) }
      maxColoursInVariant = max(maxColoursInVariant, variantColours.count)
      current = []
      colourOrder = []
      variantColours = []
    }
    for piece in pieces {
      switch piece {
      case .alternative: closeVariant()
      case .op(let text): current.append(text)
      case .unknown(let text, let confidence):
        reasons.append("Unrecognised text (\(text.count) characters)")
        weakest = min(weakest, confidence)
      case .tile(let text, let ink, let confidence, let exact):
        weakest = min(weakest, confidence)
        if text.contains("0") && !exact {
          reasons.append("A 0 read from a picture could be the letter O")
        }
        let (letters, substituted) = normaliseCharacters(text)
        if substituted { reasons.append("A character looks like 0/O or 1/I and was guessed") }
        let needsSuit = letters.contains { $0.isNumber && $0 != "0" } || letters.contains("D")
        if needsSuit {
          sawNumbers = sawNumbers || letters.contains { $0.isNumber && $0 != "0" }
          switch ink {
          case .colour(let k):
            if !colourOrder.contains(k) { colourOrder.append(k) }
            variantColours.insert(k)
            let index = colourOrder.firstIndex(of: k)!
            if index > 2 {
              reasons.append("More than three suit colours in one hand")
              current.append("\(letters)/z")
            } else {
              current.append("\(letters)/\(["x", "y", "z"][index])")
            }
          case .neutral:
            reasons.append("Suit colour not readable (grey or black ink)")
            current.append("\(letters)/x")
          case .unclear:
            reasons.append("Suit colour unclear")
            current.append("\(letters)/x")
          }
        } else {
          if case .colour = ink { reasons.append("Coloured ink on a tile that has no suit") }
          if case .unclear = ink { reasons.append("Ink colour unclear") }
          current.append(letters)
        }
      }
    }
    closeVariant()

    // 6. Notes can contradict the colours.
    let noteText = notes.joined(separator: " ").lowercased()
    if let declared = declaredSuitCount(in: noteText), maxColoursInVariant > 0,
      declared != maxColoursInVariant
    {
      reasons.append("Note says \(declared) suits but \(maxColoursInVariant) colours were seen")
    }
    let noteImpliesNumberRule =
      noteText.contains("consec") || noteText.contains("like") || noteText.contains("odd")
      || noteText.contains("even")

    // 7. Shift from footnote marker or section title.
    var shift = Shift.none
    if let marker {
      if let granted = context.footnoteShifts[marker] {
        shift = granted
      } else {
        reasons.append("Footnote mark has no explanation on the page")
      }
    } else if sawNumbers, sectionImpliesShift(context.sectionTitle) {
      shift = .consecutive
      reasons.append("Section title suggests the numbers can shift; confirm which numbers are allowed")
    } else if noteImpliesNumberRule && sawNumbers {
      reasons.append("Note mentions a number rule; check whether the numbers can shift")
    }
    if shift != .none && !sawNumbers { shift = .none }

    if weakest < config.minimumConfidence { reasons.append("Text was hard to read") }
    if variantSources.isEmpty { reasons.append("No hand pattern found") }

    // 8. Parse with the app's own parser.
    var line: CardLine?
    var parseFailure = false
    if !variantSources.isEmpty {
      let pointText = points.map(String.init) ?? "25"
      let exposureText = (exposure ?? false) ? "C" : "X"
      var text = variantSources.joined(separator: " | ") + " ; \(pointText) ; \(exposureText)"
      if shift != .none { text += " ;  ; " + (shift == .consecutive ? "shift" : "shift2") }
      switch Notation.parseLine(text) {
      case .success(let parsed): line = parsed
      case .failure(let failure):
        parseFailure = true
        for error in failure.errors { reasons.append("Not a valid hand: \(error.code.rawValue)") }
      }
    }

    let state: ScanReviewState
    if line == nil {
      state = .cannotRead
    } else if reasons.isEmpty {
      state = .ready
    } else {
      state = parseFailure ? .cannotRead : .needsCheck
    }
    return ScanCandidate(
      page: row.page, rect: row.rect, rawText: row.text, state: state, line: line,
      reasons: Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons)
  }

  // MARK: Helpers

  public static func clean(_ text: String) -> String {
    text.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:·•_"))
  }

  static func isLeader(_ text: String) -> Bool {
    text.count >= 2 && text.allSatisfy { ".·…•_-–—".contains($0) }
  }

  static func isAlternative(_ text: String) -> Bool {
    let stripped = text.trimmingCharacters(in: CharacterSet(charactersIn: "-–—~ "))
    return stripped.lowercased() == "or" || text == "|"
  }

  public struct ExposureForm {
    public var concealed: Bool
    public var points: Int?
  }

  public static func exposureForm(_ text: String) -> ExposureForm? {
    guard let first = text.first, let last = text.last else { return nil }
    if text == "X" || text == "C" { return ExposureForm(concealed: text == "C", points: nil) }
    if "XC".contains(first), let value = pointsValue(String(text.dropFirst())), text.count >= 2 {
      return ExposureForm(concealed: first == "C", points: value)
    }
    if "XC".contains(last), let value = pointsValue(String(text.dropLast())), text.count >= 2 {
      return ExposureForm(concealed: last == "C", points: value)
    }
    return nil
  }

  public static func pointsValue(_ text: String) -> Int? {
    guard text.count >= 2, text.count <= 3, text.allSatisfy(\.isASCII), let value = Int(text),
      (1...500).contains(value)
    else { return nil }
    return value
  }

  /// Letters and digits that could be a tile body, allowing O/I look-alikes inside digit tokens.
  public static func isTileLike(_ text: String) -> Bool {
    guard !text.isEmpty else { return false }
    let hasDigit = text.contains { $0.isNumber }
    let onlyOs = text.allSatisfy { $0 == "O" }
    for ch in text {
      if ch.isNumber && ch.isASCII { continue }
      if tileLetters.contains(ch) { continue }
      if (ch == "O" || ch == "I") && (hasDigit || onlyOs) { continue }
      return false
    }
    return true
  }

  static func normaliseCharacters(_ text: String) -> (String, Bool) {
    var substituted = false
    var out = ""
    for ch in text {
      switch ch {
      case "O": out.append("0"); substituted = true
      case "I": out.append("1"); substituted = true
      default: out.append(ch)
      }
    }
    return (out, substituted)
  }

  static func declaredSuitCount(in note: String) -> Int? {
    guard let range = note.range(of: "suit") else { return nil }
    let before = note[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
    guard let last = before.last, let value = last.wholeNumberValue, (1...3).contains(value) else {
      return nil
    }
    return value
  }

  /// "2026" followed by a "[red]" token, or "2026[red]" in one token, becomes a coloured token. This is the
  /// retyped-table convention: colour words instead of coloured ink.
  static func attachColourWords(_ tokens: [ScanToken]) -> [ScanToken] {
    var out: [ScanToken] = []
    for token in tokens {
      let text = token.text
      if let open = text.firstIndex(of: "["), text.hasSuffix("]") {
        let word = text[text.index(after: open)..<text.index(before: text.endIndex)].lowercased()
        let prefix = String(text[..<open])
        if let k = colourWords[word] ?? (word == "black" ? -1 : nil) {
          let ink: ScanInk = k < 0 ? .neutral : .colour(k)
          if prefix.isEmpty, var last = out.popLast() {
            last.ink = ink
            out.append(last)
          } else if !prefix.isEmpty {
            var copy = token
            copy.text = prefix
            copy.ink = ink
            out.append(copy)
          }
          continue
        }
      }
      out.append(token)
    }
    return out
  }
}
