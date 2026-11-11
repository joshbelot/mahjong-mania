import Foundation
import MahjongCore

/// The seven source formats of NEXT_WAVES_SPEC §4.4. Each is a reported class.
public enum SourceFormat: String, Codable, CaseIterable {
  case phonePhoto = "phone-photo"
  case textPDF = "text-pdf"
  case imagePDF = "image-pdf"
  case screenshot
  case grayscale
  case screenPhoto = "screen-photo"
  case retyped

  public var fileExtension: String {
    switch self {
    case .textPDF, .imagePDF: return "pdf"
    case .phonePhoto, .screenPhoto: return "jpg"
    default: return "png"
    }
  }
}

public enum Split: String, Codable { case dev, heldOut = "held-out" }

public enum Ambiguity: String, Codable {
  case missingPoints, missingExposure, zeroLetter, blot, faint
}

public struct RowSpec {
  public var hand: PoolHand
  public var ambiguity: Ambiguity?
  public var marker: String?
  public var id: String
}

public struct SectionSpec {
  public var title: String
  /// When set, every row in the section has this shift because of the section title (section scope).
  public var sectionShift: ShiftScope?
  public var rows: [RowSpec]
}

public struct PageSpec {
  public var id: String
  public var split: Split
  public var format: SourceFormat
  public var layout: String
  public var sections: [SectionSpec]
  public var footnotes: [(marker: String, text: String)]
}

// MARK: Manifest (committed)

public struct ManifestRow: Codable {
  public var id: String
  public var kind: ScanTruthKind
  /// Card-file text of the intended hand. Original content, safe to commit.
  public var line: String
  public var ambiguity: Ambiguity?
}

public struct ManifestPage: Codable {
  public var id: String
  public var split: Split
  public var format: SourceFormat
  public var layout: String
  public var file: String
  public var rows: [ManifestRow]
}

public enum PoorKind: String, Codable, CaseIterable {
  case heavyBlur = "heavy-blur"
  case veryDark = "very-dark"
  case largeGlare = "large-glare"
  case cutOff = "cut-off"
  case notACard = "not-a-card"
}

public struct ManifestPoor: Codable {
  public var id: String
  public var split: Split
  public var kind: PoorKind
  public var derivedFrom: String
  public var file: String
}

public struct Manifest: Codable {
  public var version: Int
  public var seed: UInt64
  public var pages: [ManifestPage]
  public var poorSources: [ManifestPoor]
}
