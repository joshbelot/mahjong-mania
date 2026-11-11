import Foundation

/// Experimental card-scanning types (SPEC 1.5, Phase 39). Foundation-only: no Vision, PDFKit or UIKit.
/// Rectangles are normalised to 0...1 in an upright page coordinate system with the origin at the top-left.
public struct ScanRect: Hashable, Codable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public var midX: Double { x + width / 2 }
  public var midY: Double { y + height / 2 }
  public var maxX: Double { x + width }
  public var maxY: Double { y + height }

  public func union(_ other: ScanRect) -> ScanRect {
    let minX = min(x, other.x)
    let minY = min(y, other.y)
    return ScanRect(
      x: minX, y: minY, width: max(maxX, other.maxX) - minX, height: max(maxY, other.maxY) - minY)
  }
}

/// The ink a recognised word was printed in. Colours are clustered per page by the platform layer, so
/// `colour(k)` only means "the same ink as every other `colour(k)` on this page", never a fixed suit.
public enum ScanInk: Hashable, Codable, Sendable {
  /// Black or dark grey: not a suit colour.
  case neutral
  case colour(Int)
  /// The platform layer could not decide (for example a word spanning two inks, or very faint ink).
  case unclear
}

public struct ScanToken: Hashable, Codable, Sendable {
  public var text: String
  public var ink: ScanInk
  /// 0...1 recognition confidence from the platform layer (1 for a PDF text layer).
  public var confidence: Double
  public var rect: ScanRect
  /// True when the characters come from a PDF text layer rather than from recognition, so a `0` really is
  /// a zero and not a letter O that the recogniser chose to call one.
  public var exactText: Bool

  public init(text: String, ink: ScanInk, confidence: Double, rect: ScanRect, exactText: Bool = false) {
    self.text = text
    self.ink = ink
    self.confidence = confidence
    self.rect = rect
    self.exactText = exactText
  }
}

public struct ScanRow: Hashable, Codable, Sendable {
  public var page: Int
  /// Tokens left to right.
  public var tokens: [ScanToken]
  public var rect: ScanRect

  public init(page: Int, tokens: [ScanToken]) {
    self.page = page
    self.tokens = tokens
    var union = tokens.first?.rect ?? ScanRect(x: 0, y: 0, width: 0, height: 0)
    for token in tokens.dropFirst() { union = union.union(token.rect) }
    self.rect = union
  }

  public var text: String { tokens.map(\.text).joined(separator: " ") }
}

public enum ScanReviewState: String, Codable, Sendable {
  /// "Ready to review": every field resolved and the structure is valid. Not "correct".
  case ready
  /// "Needs a check": a draft exists but something is unresolved or uncertain.
  case needsCheck
  /// "Can't read this line".
  case cannotRead
}

public struct ScanCandidate: Hashable, Codable, Sendable {
  public var page: Int
  public var rect: ScanRect
  public var rawText: String
  public var state: ScanReviewState
  /// The proposed hand, when one could be built. Present for `needsCheck` rows too.
  public var line: CardLine?
  public var reasons: [String]

  public init(
    page: Int, rect: ScanRect, rawText: String, state: ScanReviewState, line: CardLine?,
    reasons: [String]
  ) {
    self.page = page
    self.rect = rect
    self.rawText = rawText
    self.state = state
    self.line = line
    self.reasons = reasons
  }

  public var semanticKey: String? { line.map { ScanSemantics.key($0) } }
}

/// Page-level facts the row interpreter needs from the layout analysis.
public struct ScanPageContext: Hashable, Codable, Sendable {
  /// Footnote marker (`*`, `**`, `†`) to the shift it grants. A marker that is missing here is unresolved.
  public var footnoteShifts: [String: Shift]
  /// Title of the section the row sits in, if one was detected.
  public var sectionTitle: String?

  public init(footnoteShifts: [String: Shift] = [:], sectionTitle: String? = nil) {
    self.footnoteShifts = footnoteShifts
    self.sectionTitle = sectionTitle
  }
}
