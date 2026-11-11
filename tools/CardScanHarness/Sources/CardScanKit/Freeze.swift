import CryptoKit
import Foundation
import MahjongCore

/// The frozen experiment definition. Written from the development run and committed BEFORE the held-out run.
/// The held-out run refuses to start if the corpus or manifest no longer matches the freeze.
public struct Freeze: Codable {
  public var frozenOn: String
  public var manifestSHA256: String
  public var devPages: [String]
  public var heldOutPages: [String]
  public var supportedFormats: [String]
  public var unsupportedLayouts: [String]
  public var gateDenominator: String
  public var gate: String
  public var quality: QualityThresholds
  public var minimumConfidence: Double
  public var inkMinChromaDistance: Double
  public var inkMaxBlackValue: Double
  public var layoutGapHeights: Double
  public var devMedianSeconds: Double
  public var devMaxSeconds: Double
  public var devMaxPeakMB: Double
  public var budgetMedianSecondsPerPage: Double
  public var budgetMaxSecondsPerPage: Double
  public var budgetPeakMB: Double

  public static func sha256(of url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
  }

  public static func make(manifest: Manifest, manifestURL: URL, dev: SplitReport, date: String) throws -> Freeze {
    let secs = dev.seconds.sorted()
    let median = secs.isEmpty ? 0 : secs[secs.count / 2]
    let maxSecs = secs.last ?? 0
    let maxMB = dev.rssMB.max() ?? 0
    let config = PipelineConfig()
    return Freeze(
      frozenOn: date, manifestSHA256: try sha256(of: manifestURL),
      devPages: manifest.pages.filter { $0.split == .dev }.map(\.id),
      heldOutPages: manifest.pages.filter { $0.split == .heldOut }.map(\.id),
      supportedFormats: SourceFormat.allCases.map(\.rawValue),
      unsupportedLayouts: [
        "Fixed-suit notation (a hand that names Cracks, Bams or Dots instead of printing a colour)",
        "Pages where the pattern is split over several printed lines",
        "Row text rotated more than about 15 degrees after page correction",
      ],
      gateDenominator:
        "Every readable (non-ambiguous) row of every held-out page of every format, grayscale and photo-of-screen included. Omitted rows count as failures. Rows are never removed after the run.",
      gate:
        "Exact drafts >= 60% of the denominator overall; every ambiguous row flagged or rejected; zero ready-but-wrong (incl. spurious ready rows); quality check rejects >= 90% of poor held-out sources and accepts every clean one; per-format below 60% must be labelled limited.",
      quality: QualityThresholds(), minimumConfidence: config.interpreter.minimumConfidence,
      inkMinChromaDistance: config.ink.minChromaDistance, inkMaxBlackValue: config.ink.maxBlackValue,
      layoutGapHeights: config.layout.gapHeights, devMedianSeconds: median, devMaxSeconds: maxSecs,
      devMaxPeakMB: maxMB, budgetMedianSecondsPerPage: (median * 2).rounded(.up),
      budgetMaxSecondsPerPage: (maxSecs * 2).rounded(.up), budgetPeakMB: (maxMB * 1.5 / 50).rounded(.up) * 50)
  }

  /// Throws a readable message when the corpus no longer matches the freeze.
  public func verify(manifestURL: URL) throws {
    let current = try Freeze.sha256(of: manifestURL)
    guard current == manifestSHA256 else {
      throw NSError(domain: "freeze", code: 1, userInfo: [NSLocalizedDescriptionKey: "manifest changed since the freeze; refusing to run held-out"])
    }
    let t = QualityThresholds()
    guard t.minSharpness == quality.minSharpness, t.glareMinFraction == quality.glareMinFraction,
      t.minPaperBrightness == quality.minPaperBrightness, PipelineConfig().ink.minChromaDistance == inkMinChromaDistance,
      PipelineConfig().layout.gapHeights == layoutGapHeights
    else {
      throw NSError(domain: "freeze", code: 2, userInfo: [NSLocalizedDescriptionKey: "thresholds changed since the freeze; refusing to run held-out"])
    }
  }
}
