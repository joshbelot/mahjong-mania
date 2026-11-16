import CoreGraphics
import Foundation
import MahjongCore
import Vision

/// Apple Vision text recognition. On-device only; no network.
public enum OCR {
  public static func recognize(_ image: CGImage, minimumTextHeight: Float = 0) -> [RawWord] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Card codes are not words: language correction would "fix" 2222 or NNN into something else.
    request.usesLanguageCorrection = false
    request.minimumTextHeight = minimumTextHeight
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    guard (try? handler.perform([request])) != nil, let results = request.results else { return [] }
    var words: [RawWord] = []
    for observation in results {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let string = candidate.string
      var index = string.startIndex
      while index < string.endIndex {
        while index < string.endIndex, string[index].isWhitespace { index = string.index(after: index) }
        guard index < string.endIndex else { break }
        var end = index
        while end < string.endIndex, !string[end].isWhitespace { end = string.index(after: end) }
        let range = index..<end
        let text = String(string[range])
        var rect: CGRect?
        if let box = try? candidate.boundingBox(for: range) { rect = box.boundingBox }
        if rect == nil { rect = proportional(observation.boundingBox, string: string, range: range) }
        if let r = rect {
          words.append(
            RawWord(
              text: text,
              rect: ScanRect(x: Double(r.minX), y: Double(1 - r.maxY), width: Double(r.width), height: Double(r.height)),
              confidence: Double(candidate.confidence)))
        }
        index = end
      }
    }
    return words
  }

  private static func proportional(_ box: CGRect, string: String, range: Range<String.Index>) -> CGRect {
    let total = Double(max(string.count, 1))
    let lo = Double(string.distance(from: string.startIndex, to: range.lowerBound)) / total
    let hi = Double(string.distance(from: string.startIndex, to: range.upperBound)) / total
    return CGRect(x: box.minX + box.width * lo, y: box.minY, width: box.width * (hi - lo), height: box.height)
  }

  /// Quadrilateral of the largest document-like region, in normalised coordinates with a bottom-left origin.
  public static func documentQuad(_ image: CGImage) -> (tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint)? {
    let request = VNDetectDocumentSegmentationRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    guard (try? handler.perform([request])) != nil, let o = request.results?.first else { return nil }
    return (o.topLeft, o.topRight, o.bottomLeft, o.bottomRight)
  }
}
