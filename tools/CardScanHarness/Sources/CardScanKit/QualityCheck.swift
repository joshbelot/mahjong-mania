import CoreGraphics
import Foundation
import MahjongCore

/// The whole-photo quality check of NEXT_WAVES_SPEC §5.1 step 3a, prototyped for the experiment.
/// Thresholds are tuned on the development set and frozen before the held-out run.
public enum QualityProblem: String, Codable, CaseIterable {
  case blurry, tooDark, glare, cutOff, tooFar, notACard

  /// The plain, specific fix shown to the person (copy from the spec).
  public var message: String {
    switch self {
    case .blurry: return "Too blurry. Hold the phone steady, or tap to focus."
    case .tooDark: return "Too dark. Move to better light."
    case .glare: return "Glare on the card. Tilt it away from the light."
    case .cutOff: return "Part of the card is cut off. Fit the whole panel in the frame."
    case .tooFar: return "Too far away. Move closer, or scan one panel at a time."
    case .notACard: return "This doesn't look like a card."
    }
  }
}

public struct QualityThresholds: Codable {
  public var minSharpness = 0.25
  public var minPaperBrightness = 0.55
  public var glareMinFraction = 0.065
  public var glareMaxFraction = 0.85
  public var cutOffEdgeWords = 2
  public var cutOffPaperEdge = 0.5
  public var minWordHeightPx = 9.0
  public var minTileWords = 8
  public init() {}
}

public struct QualityMetrics: Codable {
  public var sharpness = 0.0
  public var paperBrightness = 0.0
  public var clippedFraction = 0.0
  public var paperEdge = 0.0
  public var edgeWords = 0
  public var medianWordPx = 0.0
  public var tileWords = 0
}

public enum QualityCheck {
  /// Image-only measures: sharpness, light, glare. Cheap; runs before reading.
  public static func imageMetrics(_ image: CGImage) -> (sharp: Double, p90: Double, clipped: Double, paperEdge: Double) {
    let targetW = min(1600, image.width)
    let targetH = max(1, image.height * targetW / image.width)
    var gray = [UInt8](repeating: 0, count: targetW * targetH)
    gray.withUnsafeMutableBytes { raw in
      if let ctx = CGContext(
        data: raw.baseAddress, width: targetW, height: targetH, bitsPerComponent: 8, bytesPerRow: targetW,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
      {
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
      }
    }
    let n = targetW * targetH
    // Sharpness: the 99.5th percentile of the local gradient. Blur removes the strong edges of text.
    var hist = [Int](repeating: 0, count: 256)
    for y in 1..<(targetH - 1) {
      for x in 1..<(targetW - 1) {
        let i = y * targetW + x
        let gx = abs(Int(gray[i + 1]) - Int(gray[i - 1]))
        let gy = abs(Int(gray[i + targetW]) - Int(gray[i - targetW]))
        hist[min(255, max(gx, gy))] += 1
      }
    }
    func percentile(_ h: [Int], _ p: Double) -> Int {
      let total = h.reduce(0, +)
      var acc = 0
      for (v, c) in h.enumerated() {
        acc += c
        if Double(acc) >= Double(total) * p { return v }
      }
      return 255
    }
    let sharp = Double(percentile(hist, 0.995)) / 255
    var lumHist = [Int](repeating: 0, count: 256)
    var clipped = 0
    var bright = 0
    for v in gray {
      lumHist[Int(v)] += 1
      if v >= 252 { clipped += 1 }
      if v >= 190 { bright += 1 }
    }
    let p90 = Double(percentile(lumHist, 0.9)) / 255
    // Paper touching the frame edge, for photos where the card does not fill the picture.
    var edge = 0.0
    if Double(bright) / Double(n) < 0.85 {
      func fraction(_ idx: [Int]) -> Double {
        Double(idx.filter { gray[$0] >= 190 }.count) / Double(max(1, idx.count))
      }
      let left = (0..<targetH).map { $0 * targetW + 1 }
      let right = (0..<targetH).map { $0 * targetW + targetW - 2 }
      let top = (0..<targetW).map { targetW + $0 }
      let bottom = (0..<targetW).map { (targetH - 2) * targetW + $0 }
      edge = max(fraction(left), fraction(right), fraction(top), fraction(bottom))
    }
    return (sharp, p90, Double(clipped) / Double(n), edge)
  }

  public static func assess(
    original image: CGImage, wordImageHeight: Int, words: [RawWord], isTextLayer: Bool,
    thresholds t: QualityThresholds = QualityThresholds()
  ) -> (QualityMetrics, [QualityProblem]) {
    var m = QualityMetrics()
    var problems: [QualityProblem] = []
    let tileWords = words.filter { ScanRowInterpreter.isTileLike(ScanRowInterpreter.clean($0.text)) }
    m.tileWords = tileWords.count
    if !isTextLayer {
      let r = imageMetrics(image)
      m.sharpness = r.sharp
      m.paperBrightness = r.p90
      m.clippedFraction = r.clipped
      m.paperEdge = r.paperEdge
      let H = Double(wordImageHeight)
      let heights = words.map { $0.rect.height * H }.sorted()
      m.medianWordPx = heights.isEmpty ? 0 : heights[heights.count / 2]
      m.edgeWords = words.filter {
        $0.rect.x < 0.006 || $0.rect.maxX > 0.994 || $0.rect.y < 0.006 || $0.rect.maxY > 0.994
      }.count
      if r.sharp < t.minSharpness { problems.append(.blurry) }
      if r.p90 < t.minPaperBrightness { problems.append(.tooDark) }
      if r.clipped >= t.glareMinFraction && r.clipped <= t.glareMaxFraction { problems.append(.glare) }
      if m.tileWords < t.minTileWords {
        problems.append(.notACard)
      } else {
        if m.edgeWords >= t.cutOffEdgeWords || m.paperEdge >= t.cutOffPaperEdge { problems.append(.cutOff) }
        if m.medianWordPx < t.minWordHeightPx { problems.append(.tooFar) }
      }
    } else if m.tileWords < t.minTileWords {
      problems.append(.notACard)
    }
    return (m, problems)
  }
}
