import Foundation

private struct RawToken {
  var start: Int
  var end: Int
  var text: String
}

private let bodyCharacters: Set<Character> = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "F", "N", "E", "W", "S", "R", "G", "D",
]
private let operatorTokens: Set<String> = ["+", "=", "-", "x"]
private let maxHandTiles = 14

private func splitRanges(_ chars: [Character], on separator: Character, in range: Range<Int>) -> [Range<Int>] {
  var parts: [Range<Int>] = []
  var start = range.lowerBound
  for i in range where chars[i] == separator {
    parts.append(start..<i)
    start = i + 1
  }
  parts.append(start..<range.upperBound)
  return parts
}

private func rawTokens(_ chars: [Character], in range: Range<Int>) -> [RawToken] {
  var result: [RawToken] = []
  var i = range.lowerBound
  while i < range.upperBound {
    if chars[i].isWhitespace {
      i += 1
      continue
    }
    var j = i
    while j < range.upperBound && !chars[j].isWhitespace { j += 1 }
    result.append(RawToken(start: i, end: j, text: String(chars[i..<j])))
    i = j
  }
  return result
}

private func suitRef(for character: Character) -> SuitRef? {
  switch character {
  case "x": return .variable(.x)
  case "y": return .variable(.y)
  case "z": return .variable(.z)
  case "c": return .fixed(.cracks)
  case "b": return .fixed(.bams)
  case "d": return .fixed(.dots)
  default: return nil
  }
}

private let suitHelp = "Use /x, /y, /z for any suit or /c, /b, /d for Cracks, Bams, Dots"

extension Notation {
  // MARK: Line parsing

  public static func parseLine(
    _ text: String, id: String? = nil, section: String = "Hands", indexInSection: Int = 1
  ) -> Result<CardLine, ParseErrorList> {
    let chars = Array(text)
    if chars.allSatisfy({ $0.isWhitespace }) {
      return .failure(
        ParseErrorList(errors: [
          ParseError(
            code: .empty, message: "Type a hand, for example: FF 2222/x 4444/y 66/z ; 25 ; X",
            range: 0..<chars.count)
        ]))
    }

    var errors: [ParseError] = []
    let fields = splitRanges(chars, on: ";", in: 0..<chars.count)
    if fields.count > 5 {
      errors.append(
        ParseError(
          code: .tooManyFields,
          message: "A line has at most 5 parts: pattern ; points ; X or C ; name ; flags",
          range: fields[5].lowerBound - 1..<chars.count))
    }

    // Pattern(s)
    var variants: [PatternVariant] = []
    let patternField = fields[0]
    for variantRange in splitRanges(chars, on: "|", in: patternField) {
      let (variant, variantErrors) = parseVariant(chars, in: variantRange)
      errors.append(contentsOf: variantErrors)
      if let variant { variants.append(variant) }
    }

    // Points
    var points = 0
    if fields.count > 1 {
      let tokens = rawTokens(chars, in: fields[1])
      if tokens.count == 1, let value = Int(tokens[0].text), value >= 1, value <= 500,
        tokens[0].text.allSatisfy({ $0.isASCII && $0.isNumber })
      {
        points = value
      } else {
        let range = tokens.first.map { $0.start..<($0.end) } ?? fields[1]
        errors.append(
          ParseError(code: .badPoints, message: "Points must be a whole number from 1 to 500", range: range))
      }
    } else {
      errors.append(
        ParseError(
          code: .badPoints, message: "Add the points after a semicolon, e.g. ; 25 ; X",
          range: chars.count..<chars.count))
    }

    // Exposure
    var concealed = false
    if fields.count > 2 {
      let tokens = rawTokens(chars, in: fields[2])
      if tokens.count == 1, tokens[0].text == "X" || tokens[0].text == "C" {
        concealed = tokens[0].text == "C"
      } else {
        let range = tokens.first.map { $0.start..<($0.end) } ?? fields[2]
        errors.append(
          ParseError(
            code: .badExposure, message: "Write X for an exposed hand or C for a concealed hand", range: range))
      }
    } else {
      errors.append(
        ParseError(
          code: .badExposure, message: "Add X (exposed) or C (concealed) after the points, e.g. ; 25 ; X",
          range: chars.count..<chars.count))
    }

    // Name
    var name: String?
    if fields.count > 3 {
      let trimmed = String(chars[fields[3]]).trimmingCharacters(in: .whitespaces)
      name = trimmed.isEmpty ? nil : trimmed
    }

    // Flags
    var shift = Shift.none
    var flagRange: Range<Int>?
    if fields.count > 4 {
      for token in rawTokens(chars, in: fields[4]) {
        let range = token.start..<token.end
        let flag: Shift
        switch token.text {
        case "shift": flag = .consecutive
        case "shift2": flag = .parity
        default:
          errors.append(
            ParseError(
              code: .badFlag, message: "Unknown flag '\(token.text)'. Use shift or shift2", range: range))
          continue
        }
        if shift != .none && shift != flag {
          errors.append(
            ParseError(code: .badFlag, message: "Use either shift or shift2, not both", range: range))
        } else {
          shift = flag
          flagRange = flagRange ?? range
        }
      }
    }

    if shift != .none, !variants.isEmpty {
      let hasDigits = variants.contains { !Instantiate.digits(in: $0.groups).isEmpty }
      if !hasDigits {
        errors.append(
          ParseError(
            code: .shiftNoNumbers, message: "This hand has no numbers 1–9, so it can't shift",
            range: flagRange ?? 0..<0))
      }
    }

    if !errors.isEmpty {
      let sorted = errors.enumerated().sorted {
        if $0.element.range.lowerBound != $1.element.range.lowerBound {
          return $0.element.range.lowerBound < $1.element.range.lowerBound
        }
        return $0.offset < $1.offset
      }.map(\.element)
      return .failure(ParseErrorList(errors: sorted))
    }

    var line = CardLine(
      id: "", section: section, name: name, points: points, concealed: concealed, shift: shift,
      variants: variants, source: "", indexInSection: indexInSection)
    line.source = serialize(line)
    line.id = id ?? "L_" + fnv1aBase36(line.source)
    return .success(line)
  }

  // MARK: Variants

  private static func parseVariant(
    _ chars: [Character], in range: Range<Int>
  ) -> (PatternVariant?, [ParseError]) {
    let tokens = rawTokens(chars, in: range)
    guard let first = tokens.first, let last = tokens.last else {
      return (
        nil,
        [
          ParseError(
            code: .empty, message: "This hand has no tiles. Add groups like FF or 2222/x", range: range)
        ]
      )
    }
    let variantRange = first.start..<last.end

    var errors: [ParseError] = []
    var patternTokens: [PatternToken] = []
    var source = ""

    for token in tokens {
      if operatorTokens.contains(token.text) {
        if !source.isEmpty { source += " " }
        let start = source.count
        source += token.text
        patternTokens.append(.op(token.text, range: start..<source.count))
        continue
      }
      switch parseGroupToken(token) {
      case .failure(let tokenErrors):
        errors.append(contentsOf: tokenErrors.errors)
      case .success(let runs):
        if !source.isEmpty { source += " " }
        let tokenStart = source.count
        source += token.text
        for run in runs {
          patternTokens.append(
            .group(run.spec, range: (tokenStart + run.offset)..<(tokenStart + run.offset + run.spec.count)))
        }
      }
    }

    if !errors.isEmpty { return (nil, errors) }

    let variant = PatternVariant(tokens: patternTokens, source: source)
    let groups = variant.groups

    let total = groups.reduce(0) { $0 + $1.count }
    if total != maxHandTiles {
      errors.append(
        ParseError(
          code: .tileCount, message: "This hand has \(total) tiles; a hand needs \(maxHandTiles)",
          range: variantRange))
    }

    let variables = Instantiate.variables(in: groups)
    let fixed = Instantiate.fixedSuits(in: groups)
    if variables.count + fixed.count > 3 {
      errors.append(
        ParseError(
          code: .badSuit,
          message: "A hand can use at most 3 different suits (variables and fixed suits together)",
          range: variantRange))
    }

    if errors.isEmpty {
      let bindings = Instantiate.assignments(variables: variables, excluding: fixed)
      var firstViolation: Tile?
      var supplyOK = bindings.isEmpty
      for binding in bindings {
        let resolved: [(tile: Tile, count: Int)] = groups.compactMap { group in
          Instantiate.resolve(group.tile, binding: binding).map { ($0, group.count) }
        }
        if let violation = Instantiate.supplyViolation(resolved) {
          firstViolation = firstViolation ?? violation
        } else {
          supplyOK = true
          break
        }
      }
      if !supplyOK {
        let tileName = firstViolation?.name ?? "tiles"
        errors.append(
          ParseError(
            code: .tooManyOfTile, message: "This hand needs more \(tileName) tiles than a set has",
            range: variantRange))
      }
    }

    return errors.isEmpty ? (variant, []) : (nil, errors)
  }

  private struct Run {
    var spec: GroupSpec
    var offset: Int
  }

  private static func parseGroupToken(_ token: RawToken) -> Result<[Run], ErrorBundle> {
    let tokenChars = Array(token.text)
    var errors: [ParseError] = []

    var bodyChars = tokenChars
    var ref: SuitRef?
    if let slash = tokenChars.firstIndex(of: "/") {
      bodyChars = Array(tokenChars[..<slash])
      let suitChars = Array(tokenChars[(slash + 1)...])
      if suitChars.count == 1, let parsed = suitRef(for: suitChars[0]) {
        ref = parsed
      } else {
        errors.append(
          ParseError(
            code: .badSuit, message: "'\(String(suitChars))' isn't a suit. \(suitHelp)",
            range: (token.start + slash)..<token.end))
      }
    }

    if bodyChars.isEmpty {
      errors.append(
        ParseError(
          code: .badChar, message: "Add tiles before the suit, e.g. 2222/x",
          range: token.start..<token.end))
    }
    for (i, c) in bodyChars.enumerated() where !bodyCharacters.contains(c) {
      errors.append(
        ParseError(
          code: .badChar,
          message: "'\(c)' isn't a tile. Use 1–9, F (flower), N E W S (winds), R G 0 (dragons) or D",
          range: (token.start + i)..<(token.start + i + 1)))
    }
    if !errors.isEmpty { return .failure(ErrorBundle(errors: errors)) }

    let bodyRange = token.start..<(token.start + bodyChars.count)
    var runs: [Run] = []
    var missingSuitReported = false
    var i = 0
    while i < bodyChars.count {
      let c = bodyChars[i]
      var j = i
      while j < bodyChars.count && bodyChars[j] == c { j += 1 }
      let length = j - i
      let runRange = (token.start + i)..<(token.start + j)

      let limit = c == "F" ? 8 : 6
      if length > limit {
        errors.append(
          ParseError(
            code: .groupTooBig,
            message: "A group can have at most 6 tiles (8 for flowers), but this one has \(length)",
            range: runRange))
      }

      let spec: TileSpec?
      switch c {
      case "1", "2", "3", "4", "5", "6", "7", "8", "9":
        if let ref, let value = Int(String(c)) {
          spec = .number(value, ref)
        } else {
          spec = nil
          if !missingSuitReported {
            missingSuitReported = true
            errors.append(
              ParseError(
                code: .missingSuit,
                message: "Number tiles need a suit: add /x, /y, /z (any suit) or /c, /b, /d (Cracks, Bams, Dots)",
                range: bodyRange))
          }
        }
      case "D":
        if let ref {
          spec = .matchingDragon(ref)
        } else {
          spec = nil
          if !missingSuitReported {
            missingSuitReported = true
            errors.append(
              ParseError(
                code: .missingSuit,
                message: "D (the dragon matching a suit) needs a suit: add /x, /y, /z or /c, /b, /d",
                range: bodyRange))
          }
        }
      case "0": spec = .fixed(.dragon(.white))
      case "F": spec = .fixed(.flower)
      case "N": spec = .fixed(.wind(.north))
      case "E": spec = .fixed(.wind(.east))
      case "W": spec = .fixed(.wind(.west))
      case "S": spec = .fixed(.wind(.south))
      case "R": spec = .fixed(.dragon(.red))
      case "G": spec = .fixed(.dragon(.green))
      default: spec = nil
      }

      if let spec { runs.append(Run(spec: GroupSpec(tile: spec, count: length), offset: i)) }
      i = j
    }

    if !errors.isEmpty { return .failure(ErrorBundle(errors: errors)) }
    return .success(runs)
  }

  private struct ErrorBundle: Error {
    var errors: [ParseError]
  }

  // MARK: Hashing

  /// 32-bit FNV-1a of the UTF-8 bytes, in base 36 (used for stable line IDs).
  static func fnv1aBase36(_ text: String) -> String {
    var hash: UInt32 = 0x811C_9DC5
    for byte in text.utf8 {
      hash ^= UInt32(byte)
      hash = hash &* 0x0100_0193
    }
    return String(hash, radix: 36)
  }
}
