import CoreGraphics
import CoreImage
import Darwin
import Foundation
import MahjongCore

public struct PageOutcome: Codable {
  public var problems: [QualityProblem]
  public var metrics: QualityMetrics
  public var handRows: Int
  public var readyRows: Int
  public var usedTextLayer: Bool
  public var straightened: Bool
  public var mostlyUnreadable: Bool
}

public struct PipelineResult: Codable {
  public var candidates: [ScanCandidate]
  public var pages: [PageOutcome]
  public var seconds: Double
  public var maxRSSBytes: Int
  public var error: String?
}

public struct PipelineConfig {
  public var interpreter = ScanInterpreterConfig()
  public var ink = InkThresholds()
  public var layout = LayoutConfig()
  public init() {}
}

public enum Pipeline {
  public static func run(url: URL, config: PipelineConfig = PipelineConfig()) -> PipelineResult {
    let start = Date()
    var candidates: [ScanCandidate] = []
    var pages: [PageOutcome] = []
    do {
      let loaded = try SourceLoader.load(url)
      for (index, page) in loaded.enumerated() {
        let (found, outcome) = process(page, index: index, config: config)
        candidates += found
        pages.append(outcome)
      }
    } catch {
      return PipelineResult(
        candidates: [], pages: [], seconds: Date().timeIntervalSince(start), maxRSSBytes: maxRSS(),
        error: "\(error)")
    }
    return PipelineResult(
      candidates: candidates, pages: pages, seconds: Date().timeIntervalSince(start), maxRSSBytes: maxRSS(),
      error: nil)
  }

  static func maxRSS() -> Int {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Int(usage.ru_maxrss)
  }

  static func process(_ page: LoadedPage, index: Int, config: PipelineConfig) -> ([ScanCandidate], PageOutcome) {
    var image = page.image
    var words: [RawWord]
    var straightened = false
    var refinedRegion = false
    let useLayer = page.textLayer != nil
    if let layer = page.textLayer {
      words = layer
    } else {
      if let corrected = straighten(image) { image = corrected; straightened = true }
      words = OCR.recognize(image)
      // The card may fill only part of the frame. Re-read just that region from the full-detail source.
      if straightened == false, let crop = page.cropAtFullResolution, let region = cardRegion(words) {
        if region.width < 0.7 || region.height < 0.7, let detailed = crop(region) {
          let refined = OCR.recognize(detailed)
          if refined.count >= words.count / 2 { image = detailed; words = refined; refinedRegion = true }
        }
      }
      // A sideways or upside-down photo: try the other orientations only when nothing hand-like was found.
      if handRowCount(words, image: image, config: config) < 2 {
        var best = (words, image, handRowCount(words, image: image, config: config))
        for turns in 1...3 {
          guard let rotated = rotate(image, quarterTurns: turns) else { continue }
          let w = OCR.recognize(rotated)
          let c = handRowCount(w, image: rotated, config: config)
          if c > best.2 { best = (w, rotated, c) }
        }
        words = best.0
        image = best.1
      }
    }

    let (metrics, problems) = QualityCheck.assess(
      original: page.image, wordImageHeight: image.height, words: words, isTextLayer: useLayer)
    var found = interpretPage(words: words, image: image, index: index, config: config)
    var secondOpinion = false
    if !useLayer, !found.isEmpty {
      // Vision reports full confidence on everything, so confidence cannot gate "ready". Instead a row is
      // only ready when a second, independent reading (different scale) produces the same hand.
      if let bigger = rescaled(image) {
        let other = interpretPage(words: OCR.recognize(bigger), image: bigger, index: index, config: config)
        found = found.map { candidate in
          guard candidate.state == .ready else { return candidate }
          let agrees = other.contains { o in
            o.state != .cannotRead && o.semanticKey == candidate.semanticKey
              && abs(o.rect.midY - candidate.rect.midY) < max(candidate.rect.height, 0.005)
              && o.rect.midX > candidate.rect.x && o.rect.midX < candidate.rect.maxX
          }
          if agrees { return candidate }
          var copy = candidate
          copy.state = .needsCheck
          copy.reasons.append("A second reading of the picture disagreed")
          return copy
        }
        secondOpinion = true
      }
    }
    _ = secondOpinion
    let ready = found.filter { $0.state == .ready }.count
    let outcome = PageOutcome(
      problems: problems, metrics: metrics, handRows: found.count, readyRows: ready,
      usedTextLayer: useLayer, straightened: straightened || refinedRegion,
      mostlyUnreadable: found.isEmpty ? false : Double(found.filter { $0.state != .cannotRead }.count) < Double(found.count) / 2)
    return (found, outcome)
  }

  static func interpretPage(words: [RawWord], image: CGImage, index: Int, config: PipelineConfig) -> [ScanCandidate] {
    let inks = InkAnalyzer.classify(words, image: image, thresholds: config.ink)
    let reading = LayoutAnalyzer.analyze(
      words: words, inks: inks, page: index, imageSize: CGSize(width: image.width, height: image.height),
      config: config.layout)
    return reading.rows.map { ScanRowInterpreter.interpret($0.row, context: $0.context, config: config.interpreter) }
  }

  /// A second view of the same page at a different scale, for the independent second reading.
  static func rescaled(_ image: CGImage) -> CGImage? {
    let long = Double(max(image.width, image.height))
    let scale = min(1.5, 4800 / long)
    guard scale > 1.1 else { return nil }
    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    guard let scaled = filter.outputImage else { return nil }
    let sharp = scaled.applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 2.0, "inputIntensity": 0.6])
    return Imaging.ciContext.createCGImage(sharp, from: scaled.extent)
  }

  static func handRowCount(_ words: [RawWord], image: CGImage, config: PipelineConfig) -> Int {
    let inks = InkAnalyzer.classify(words, image: image, thresholds: config.ink)
    return LayoutAnalyzer.analyze(
      words: words, inks: inks, page: 0, imageSize: CGSize(width: image.width, height: image.height),
      config: config.layout
    ).rows.count
  }

  /// Bounding box of the words that look like card text, padded, in normalised coordinates.
  static func cardRegion(_ words: [RawWord]) -> ScanRect? {
    let tiles = words.filter { ScanRowInterpreter.isTileLike(ScanRowInterpreter.clean($0.text)) && $0.text.count >= 2 }
    guard tiles.count >= 12 else { return nil }
    let xs = tiles.map(\.rect.x).sorted(), ys = tiles.map(\.rect.y).sorted()
    let x1s = tiles.map(\.rect.maxX).sorted(), y1s = tiles.map(\.rect.maxY).sorted()
    let lo = tiles.count / 50, hi = tiles.count - 1 - tiles.count / 50
    let (x0, x1, y0, y1) = (xs[lo], x1s[hi], ys[lo], y1s[hi])
    let padX = (x1 - x0) * 0.06, padY = (y1 - y0) * 0.08
    let rx = max(0, x0 - padX), ry = max(0, y0 - padY)
    return ScanRect(x: rx, y: ry, width: min(1, x1 + padX) - rx, height: min(1, y1 + padY) - ry)
  }

  static func rotate(_ image: CGImage, quarterTurns: Int) -> CGImage? {
    let orientation: CGImagePropertyOrientation = [.right, .down, .left][quarterTurns - 1]
    let ci = CIImage(cgImage: image).oriented(orientation)
    return Imaging.ciContext.createCGImage(ci, from: ci.extent)
  }

  /// Perspective-correct a photographed page when a sensible page outline is found; otherwise leave the
  /// image alone (screenshots and flat scans are already straight).
  static func straighten(_ image: CGImage) -> CGImage? {
    guard let quad = OCR.documentQuad(image) else { return nil }
    let w = Double(image.width), h = Double(image.height)
    let pts = [quad.tl, quad.tr, quad.br, quad.bl].map { CGPoint(x: $0.x * w, y: $0.y * h) }
    var area = 0.0
    for i in 0..<4 {
      let a = pts[i], b = pts[(i + 1) % 4]
      area += Double(a.x * b.y - b.x * a.y)
    }
    let fraction = abs(area) / 2 / (w * h)
    if fraction < 0.2 || fraction > 0.97 { return nil }
    let filter = CIFilter(name: "CIPerspectiveCorrection")!
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: pts[0]), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: pts[1]), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: pts[2]), forKey: "inputBottomRight")
    filter.setValue(CIVector(cgPoint: pts[3]), forKey: "inputBottomLeft")
    guard let out = filter.outputImage else { return nil }
    return Imaging.ciContext.createCGImage(out, from: out.extent)
  }
}
