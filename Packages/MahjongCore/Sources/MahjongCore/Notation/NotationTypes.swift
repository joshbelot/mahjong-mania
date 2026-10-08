import Foundation

/// Suit variables on a card. They bind to pairwise-distinct number suits; shown to users as A, B, C.
public enum SuitVar: String, Codable, CaseIterable, Sendable {
  case x, y, z

  /// The letter shown to users: x→A, y→B, z→C.
  public var displayLetter: String {
    switch self {
    case .x: return "A"
    case .y: return "B"
    case .z: return "C"
    }
  }
}

public enum SuitRef: Hashable, Codable, Sendable {
  case variable(SuitVar)
  case fixed(Suit)
}

public enum TileSpec: Hashable, Codable, Sendable {
  case number(Int, SuitRef)  // 1...9
  case matchingDragon(SuitRef)  // D/x, D/c
  case fixed(Tile)  // winds, R, G, 0 (Soap), F
}

public struct GroupSpec: Hashable, Codable, Sendable {
  public var tile: TileSpec
  public var count: Int  // 1...8

  public init(tile: TileSpec, count: Int) {
    self.tile = tile
    self.count = count
  }
}

public enum PatternToken: Hashable, Codable, Sendable {
  /// `range` is the character range in the variant's (normalised) source. Groups that came from the same
  /// body (e.g. the four singles of `2026/x`) have adjacent ranges.
  case group(GroupSpec, range: Range<Int>)
  /// Decorative operator: "+", "=", "-" or "x".
  case op(String, range: Range<Int>)

  public var range: Range<Int> {
    switch self {
    case .group(_, let range): return range
    case .op(_, let range): return range
    }
  }
}

public struct PatternVariant: Hashable, Codable, Sendable {
  public var tokens: [PatternToken]
  /// Tokens joined by single spaces, exactly as typed but with whitespace collapsed.
  public var source: String

  public init(tokens: [PatternToken], source: String) {
    self.tokens = tokens
    self.source = source
  }

  public var groups: [GroupSpec] {
    tokens.compactMap {
      if case .group(let spec, _) = $0 { return spec }
      return nil
    }
  }
}

public enum Shift: Int, Codable, Sendable {
  case none = 0
  /// Any consecutive / like numbers (step 1).
  case consecutive = 1
  /// Keep odd/even (step 2).
  case parity = 2
}

public struct CardLine: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var section: String
  public var name: String?
  public var points: Int
  public var concealed: Bool
  public var shift: Shift
  public var variants: [PatternVariant]
  /// The canonical serialisation of the line (see `Notation.serialize`).
  public var source: String
  /// 1-based position of the line within its section; set by the card parser.
  public var indexInSection: Int

  public init(
    id: String, section: String, name: String?, points: Int, concealed: Bool, shift: Shift,
    variants: [PatternVariant], source: String, indexInSection: Int = 1
  ) {
    self.id = id
    self.section = section
    self.name = name
    self.points = points
    self.concealed = concealed
    self.shift = shift
    self.variants = variants
    self.source = source
    self.indexInSection = indexInSection
  }

  public var displayName: String {
    if let name, !name.isEmpty { return name }
    return "\(section) #\(indexInSection)"
  }

  /// True when no group in any variant can take jokers (Singles & Pairs hands).
  public var hasNoJokerGroups: Bool {
    !variants.contains { $0.groups.contains { $0.count >= 3 } }
  }
}

public struct Card: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var name: String
  public var year: Int?
  public var builtIn: Bool
  public var lines: [CardLine]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, name: String, year: Int?, builtIn: Bool, lines: [CardLine], createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.year = year
    self.builtIn = builtIn
    self.lines = lines
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Section names in order of first appearance.
  public var sections: [String] {
    var seen = Set<String>()
    var result: [String] = []
    for line in lines where seen.insert(line.section).inserted { result.append(line.section) }
    return result
  }
}

public enum ParseErrorCode: String, Codable, Sendable {
  case empty, badChar, missingSuit, suitNotAllowed, badSuit, tileCount, tooManyOfTile, badPoints,
    badExposure, badFlag, shiftNoNumbers, shiftOutOfRange, tooManyFields, groupTooBig
}

public struct ParseError: Error, Hashable, Sendable {
  public var code: ParseErrorCode
  public var message: String
  /// Character range in the text that was parsed (a whole line, for `parseLine`).
  public var range: Range<Int>

  public init(code: ParseErrorCode, message: String, range: Range<Int>) {
    self.code = code
    self.message = message
    self.range = range
  }
}

public struct ParseErrorList: Error, Hashable, Sendable {
  public var errors: [ParseError]

  public init(errors: [ParseError]) {
    self.errors = errors
  }
}

public struct CardFileError: Hashable, Sendable {
  /// 1-based line number in the file.
  public var lineNumber: Int
  public var text: String
  public var errors: [ParseError]

  public init(lineNumber: Int, text: String, errors: [ParseError]) {
    self.lineNumber = lineNumber
    self.text = text
    self.errors = errors
  }
}

public struct CardFileParseResult: Hashable, Sendable {
  public var name: String?
  public var year: Int?
  public var lines: [CardLine]
  public var errors: [CardFileError]

  public init(name: String?, year: Int?, lines: [CardLine], errors: [CardFileError]) {
    self.name = name
    self.year = year
    self.lines = lines
    self.errors = errors
  }
}

public enum Notation {}
