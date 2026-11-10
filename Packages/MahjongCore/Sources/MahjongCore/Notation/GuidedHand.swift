import Foundation

/// A second, form-friendly view of one card line (SPEC NEXT_WAVES §3.5). It holds the same `GroupSpec`s the
/// notation parser produces and writes them back as ordinary notation, so the parser and engine remain the
/// only rule authority. Lines that the form cannot represent exactly return nil from `init?(line:)` and stay
/// in the advanced editor untouched.
public struct GuidedLine: Hashable, Sendable {
  public var name: String
  public var points: Int
  public var concealed: Bool
  public var shift: Shift
  /// One group list per alternative (`|` in notation).
  public var alternatives: [[GroupSpec]]

  public static let tilesPerHand = 14

  public init(
    name: String = "", points: Int = 25, concealed: Bool = false, shift: Shift = .none,
    alternatives: [[GroupSpec]] = [[]]
  ) {
    self.name = name
    self.points = points
    self.concealed = concealed
    self.shift = shift
    self.alternatives = alternatives
  }

  /// nil when any alternative has decorative operators or no groups: those stay in Advanced.
  public init?(line: CardLine) {
    guard !line.variants.isEmpty else { return nil }
    var result: [[GroupSpec]] = []
    for variant in line.variants {
      for token in variant.tokens {
        if case .op = token { return nil }
      }
      guard !variant.groups.isEmpty else { return nil }
      result.append(variant.groups)
    }
    self.init(
      name: line.name ?? "", points: line.points, concealed: line.concealed, shift: line.shift,
      alternatives: result)
  }

  // MARK: Text

  /// Notation of one group, e.g. `2222/x`, `DD/y`, `NNNN`.
  public static func notation(of group: GroupSpec) -> String {
    let count = max(group.count, 1)
    switch group.tile {
    case .number(let value, let ref):
      return String(repeating: String(value), count: count) + "/" + letter(ref)
    case .matchingDragon(let ref):
      return String(repeating: "D", count: count) + "/" + letter(ref)
    case .fixed(let tile):
      return String(repeating: tile.code, count: count)
    }
  }

  private static func letter(_ ref: SuitRef) -> String {
    switch ref {
    case .variable(let variable): return variable.rawValue
    case .fixed(let suit): return suit.rawValue.lowercased()
    }
  }

  public static func notation(of alternative: [GroupSpec]) -> String {
    alternative.map { notation(of: $0) }.joined(separator: " ")
  }

  public var notation: String {
    alternatives.map { Self.notation(of: $0) }.joined(separator: " | ")
  }

  /// The full line the parser reads: `notation ; points ; X|C [; name] [; shift|shift2]`.
  public var composedText: String {
    let cleanName = String(name.map { $0 == ";" || $0.isNewline ? " " : $0 })
      .trimmingCharacters(in: .whitespaces)
    var text = notation + " ; \(points) ; " + (concealed ? "C" : "X")
    if !cleanName.isEmpty || shift != .none { text += " ; " + cleanName }
    switch shift {
    case .none: break
    case .consecutive: text += " ; shift"
    case .parity: text += " ; shift2"
    }
    return text
  }

  public func tileCount(ofAlternative index: Int) -> Int {
    alternatives.indices.contains(index) ? alternatives[index].reduce(0) { $0 + $1.count } : 0
  }

  // MARK: Validation

  public enum Validation: Equatable, Sendable {
    case valid(CardLine, targetCount: Int)
    case invalid([String])
  }

  /// Plain-language problems, produced by the existing parser plus the "at least one real hand" check.
  public func validate(section: String = "Hands") -> Validation {
    if alternatives.contains(where: { $0.isEmpty }) {
      return .invalid(["Add at least one group of tiles to every alternative."])
    }
    switch Notation.parseLine(composedText, id: nil, section: section) {
    case .failure(let list):
      return .invalid(list.errors.map(\.message))
    case .success(let line):
      let targets = Engine.expand(line)
      guard !targets.isEmpty else {
        return .invalid(["No real hand can be made from these groups. Check the suits and numbers."])
      }
      return .valid(line, targetCount: targets.count)
    }
  }

  /// One concrete hand this line can make (the first expansion), as tiles in group order.
  public static func exampleTiles(for line: CardLine) -> [Tile]? {
    guard let target = Engine.expand(line).first else { return nil }
    return target.groups.flatMap { Array(repeating: $0.tile, count: $0.count) }
  }

  /// The set of expanded hands, for comparing meaning rather than text.
  public static func semanticSignature(_ line: CardLine) -> Set<String> {
    Set(Engine.expand(line).map { "\($0.variantIndex):\($0.signature)" })
  }
}
