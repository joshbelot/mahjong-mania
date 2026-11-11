import CoreGraphics
import Foundation
import MahjongCore

/// Independent foreground colour analysis on the normalised image. OCR boxes are only layout hints: this
/// never claims to read a glyph's colour from an OCR character box (NEXT_WAVES_SPEC §4).
public struct PixelImage {
  public let width: Int
  public let height: Int
  public var data: [UInt8]

  public init(_ image: CGImage) {
    width = image.width
    height = image.height
    data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { raw in
      if let ctx = CGContext(
        data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      {
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      }
    }
  }
}

public struct InkReading {
  public enum Kind { case neutral, colour(hue: Double), unclear }
  public var kind: Kind
}

public struct InkThresholds {
  /// Below this saturation the ink counts as black/grey.
  public var minChromaDistance = 0.04
  /// Darker than this is black whatever the chroma (very dark pixels carry no reliable colour).
  public var maxBlackValue = 0.20
  /// Less contrast against the paper than this is "unclear".
  public var minContrast = 0.20
  public var hueGapDegrees = 35.0
  public init() {}
}

public enum InkAnalyzer {
  /// Reads one box. `rect` is normalised, origin top-left.
  nonisolated(unsafe) public static var trace: ((Int, Double, Double, Double) -> Void)?

  struct Core { var r: Double; var g: Double; var b: Double; var v: Double }

  /// The ink colour of one box, or nil when there is not enough contrast against the paper.
  static func core(_ pixels: PixelImage, rect: ScanRect, minContrast: Double) -> Core? {
    let x0 = max(0, Int((rect.x * Double(pixels.width)).rounded(.down)) - 1)
    let x1 = min(pixels.width, Int((rect.maxX * Double(pixels.width)).rounded(.up)) + 1)
    let y0 = max(0, Int((rect.y * Double(pixels.height)).rounded(.down)) - 1)
    let y1 = min(pixels.height, Int((rect.maxY * Double(pixels.height)).rounded(.up)) + 1)
    if x1 - x0 < 2 || y1 - y0 < 2 { return nil }
    var samples: [(r: Double, g: Double, b: Double)] = []
    samples.reserveCapacity((x1 - x0) * (y1 - y0))
    for y in y0..<y1 {
      var i = (y * pixels.width + x0) * 4
      for _ in x0..<x1 {
        samples.append((Double(pixels.data[i]) / 255, Double(pixels.data[i + 1]) / 255, Double(pixels.data[i + 2]) / 255))
        i += 4
      }
    }
    // Paper: mean of the brightest third.
    let byLum = samples.indices.sorted { lum(samples[$0]) > lum(samples[$1]) }
    let top = max(1, samples.count / 3)
    var paper = (r: 0.0, g: 0.0, b: 0.0)
    for k in 0..<top {
      let s = samples[byLum[k]]
      paper.r += s.r; paper.g += s.g; paper.b += s.b
    }
    paper = (paper.r / Double(top), paper.g / Double(top), paper.b / Double(top))
    let dist = samples.map { (($0.r - paper.r) * ($0.r - paper.r) + ($0.g - paper.g) * ($0.g - paper.g) + ($0.b - paper.b) * ($0.b - paper.b)).squareRoot() }
    let maxDist = dist.max() ?? 0
    if maxDist < minContrast { return nil }
    // Ink core: the strongest part of the foreground, which avoids anti-aliased edges.
    var c = (r: 0.0, g: 0.0, b: 0.0)
    var count = 0
    for (i, d) in dist.enumerated() where d >= maxDist * 0.78 {
      c.r += samples[i].r; c.g += samples[i].g; c.b += samples[i].b
      count += 1
    }
    guard count > 0 else { return nil }
    let n = Double(count)
    let (r, g, b) = (c.r / n, c.g / n, c.b / n)
    return Core(r: r, g: g, b: b, v: max(r, g, b))
  }

  /// Chromaticity: colour with brightness divided out.
  static func chroma(_ c: Core) -> (Double, Double) {
    let sum = max(c.r + c.g + c.b, 0.001)
    return (c.r / sum, c.g / sum)
  }

  static func lum(_ c: (r: Double, g: Double, b: Double)) -> Double { 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }

  static func hsv(_ c: (Double, Double, Double)) -> (Double, Double, Double) {
    let (r, g, b) = c
    let mx = max(r, g, b), mn = min(r, g, b)
    let d = mx - mn
    var h = 0.0
    if d > 0 {
      if mx == r { h = 60 * (((g - b) / d).truncatingRemainder(dividingBy: 6)) }
      else if mx == g { h = 60 * ((b - r) / d + 2) }
      else { h = 60 * ((r - g) / d + 4) }
    }
    if h < 0 { h += 360 }
    return (h, mx == 0 ? 0 : d / mx, mx)
  }

  /// Assigns every word an ink class. Colour classes are clustered per page, so they only mean "same ink as".
  /// Black ink is found per page (it is tinted by the light), and colour is measured as a distance from it.
  public static func classify(
    _ words: [RawWord], image: CGImage, thresholds t: InkThresholds = InkThresholds()
  ) -> [ScanInk] {
    let pixels = PixelImage(image)
    let cores = words.map { core(pixels, rect: $0.rect, minContrast: t.minContrast) }
    // Neutral reference: the median chromaticity of the least saturated half of the words.
    let usable = cores.compactMap { $0 }
    func sat(_ c: Core) -> Double { let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b); return mx == 0 ? 0 : (mx - mn) / mx }
    let leastSaturated = usable.sorted { sat($0) < sat($1) }.prefix(max(1, usable.count / 2))
    let refs = leastSaturated.map(chroma)
    let ref: (Double, Double) = refs.isEmpty ? (1.0 / 3, 1.0 / 3)
      : (refs.map(\.0).sorted()[refs.count / 2], refs.map(\.1).sorted()[refs.count / 2])

    func angle(_ c: Core) -> (dist: Double, deg: Double) {
      let (a, b) = chroma(c)
      let dx = a - ref.0, dy = b - ref.1
      var deg = atan2(dy, dx) * 180 / .pi
      if deg < 0 { deg += 360 }
      return ((dx * dx + dy * dy).squareRoot(), deg)
    }
    var readings: [InkReading.Kind] = []
    for (i, word) in words.enumerated() {
      guard let c = cores[i] else { trace?(i, -1, -1, -1); readings.append(.unclear); continue }
      if c.v < t.maxBlackValue { trace?(i, -2, -2, c.v); readings.append(.neutral); continue }
      let (d, deg) = angle(c)
      trace?(i, d, deg, c.v)
      if d < t.minChromaDistance { readings.append(.neutral); continue }
      // A word spanning two inks is unclear: read both halves.
      if word.text.count >= 3 {
        let r = word.rect
        let l = core(pixels, rect: ScanRect(x: r.x, y: r.y, width: r.width / 2, height: r.height), minContrast: t.minContrast)
        let rr = core(pixels, rect: ScanRect(x: r.x + r.width / 2, y: r.y, width: r.width / 2, height: r.height), minContrast: t.minContrast)
        if let l, let rr, l.v >= t.maxBlackValue, rr.v >= t.maxBlackValue {
          let (dl, al) = angle(l), (dr, ar) = angle(rr)
          if dl >= t.minChromaDistance, dr >= t.minChromaDistance, hueDistance(al, ar) > 60 {
            readings.append(.unclear); continue
          }
          if (dl < t.minChromaDistance) != (dr < t.minChromaDistance) && min(dl, dr) < t.minChromaDistance * 0.5 && max(dl, dr) > t.minChromaDistance * 1.6 {
            // Half black, half coloured: two inks in one word.
            readings.append(.unclear); continue
          }
        }
      }
      readings.append(.colour(hue: deg))
    }
    // Cluster angles around the circle.
    let hues = readings.compactMap { k -> Double? in if case .colour(let h) = k { return h }; return nil }.sorted()
    var clusters: [[Double]] = []
    for h in hues {
      if var last = clusters.last, h - last.last! <= t.hueGapDegrees {
        last.append(h); clusters[clusters.count - 1] = last
      } else { clusters.append([h]) }
    }
    if clusters.count > 1, let first = clusters.first, let last = clusters.last,
      first.first! + 360 - last.last! <= t.hueGapDegrees
    {
      clusters[0] = last + first
      clusters.removeLast()
    }
    func clusterIndex(_ hue: Double) -> Int {
      for (i, c) in clusters.enumerated() where c.contains(where: { hueDistance($0, hue) <= t.hueGapDegrees }) { return i }
      return 0
    }
    return readings.map { kind in
      switch kind {
      case .neutral: return .neutral
      case .unclear: return .unclear
      case .colour(let h): return .colour(clusterIndex(h))
      }
    }
  }

  static func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
  }
}
