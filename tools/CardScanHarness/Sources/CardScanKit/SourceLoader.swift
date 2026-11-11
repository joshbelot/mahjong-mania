import CoreGraphics
import Foundation
import ImageIO
import MahjongCore
import PDFKit

/// A word with a position in the upright page. Rect is normalised, origin top-left.
public struct RawWord {
  public var text: String
  public var rect: ScanRect
  public var confidence: Double
  public var exact = false
}

public struct LoadedPage {
  public var image: CGImage
  /// Re-decodes a normalised region of the source at higher detail (at most 12 megapixels), for a card that
  /// only fills part of the frame. `nil` when the source has no more detail to give.
  public var cropAtFullResolution: ((ScanRect) -> CGImage?)? = nil
  /// Words read straight from a PDF text layer, when the page has one. `nil` means "use OCR".
  public var textLayer: [RawWord]?
}

public enum SourceError: Error {
  case unreadable, encrypted, tooManyPages, tooLarge
}

/// Bounded loading: decoded pages are downsampled to at most 12 megapixels and a PDF is never rendered at
/// its native size (NEXT_WAVES_SPEC §5.3).
public enum SourceLoader {
  public static let maxPixels = 12_000_000
  public static let maxPages = 4
  public static let maxBytes = 30_000_000

  public static func load(_ url: URL) throws -> [LoadedPage] {
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    if size > Self.maxBytes { throw SourceError.tooLarge }
    if url.pathExtension.lowercased() == "pdf" { return try loadPDF(url) }
    let image = try loadImage(url)
    var page = LoadedPage(image: image, textLayer: nil)
    page.cropAtFullResolution = { region in cropRegion(url, region: region, previewWidth: image.width) }
    return [page]
  }

  static func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
    else { throw SourceError.unreadable }
    if w * h > 50_000_000 { throw SourceError.tooLarge }
    let longSide = Double(max(w, h))
    let target = min(longSide, (Double(Self.maxPixels) * longSide / Double(min(w, h))).squareRoot())
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(target),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw SourceError.unreadable }
    return image
  }

  static func cropRegion(_ url: URL, region: ScanRect, previewWidth: Int) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
      w > previewWidth + previewWidth / 5
    else { return nil }
    // The thumbnail applies the EXIF orientation; the full image does not, so compare in the same frame.
    let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
    guard orientation == 1, let full = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let rect = CGRect(
      x: region.x * Double(w), y: region.y * Double(h), width: region.width * Double(w), height: region.height * Double(h)
    ).integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))
    guard let cropped = full.cropping(to: rect) else { return nil }
    let pixels = cropped.width * cropped.height
    if pixels <= maxPixels { return cropped }
    let scale = (Double(maxPixels) / Double(pixels)).squareRoot()
    let ctx = Imaging.bitmap(width: Int(Double(cropped.width) * scale), height: Int(Double(cropped.height) * scale))
    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
    return ctx.makeImage()
  }

  static func loadPDF(_ url: URL) throws -> [LoadedPage] {
    guard let doc = PDFDocument(url: url) else { throw SourceError.unreadable }
    if doc.isLocked { throw SourceError.encrypted }
    if doc.pageCount > Self.maxPages { throw SourceError.tooManyPages }
    var pages: [LoadedPage] = []
    for index in 0..<doc.pageCount {
      guard let page = doc.page(at: index) else { continue }
      let box = page.bounds(for: .mediaBox)
      // About 200 dpi, never more than the pixel cap.
      var scale = 200.0 / 72.0
      let pixels = Double(box.width * box.height) * scale * scale
      if pixels > Double(Self.maxPixels) { scale *= (Double(Self.maxPixels) / pixels).squareRoot() }
      let w = Int(box.width * scale)
      let h = Int(box.height * scale)
      let ctx = Imaging.bitmap(width: w, height: h)
      ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
      ctx.scaleBy(x: scale, y: scale)
      page.draw(with: .mediaBox, to: ctx)
      guard let image = ctx.makeImage() else { continue }
      pages.append(LoadedPage(image: image, textLayer: textLayerWords(page)))
    }
    if pages.isEmpty { throw SourceError.unreadable }
    return pages
  }

  /// Words and positions from the PDF's own text layer. Needs no OCR.
  static func textLayerWords(_ page: PDFPage) -> [RawWord]? {
    guard let string = page.string,
      string.filter({ !$0.isWhitespace }).count >= 20
    else { return nil }
    let box = page.bounds(for: .mediaBox)
    let ns = string as NSString
    var words: [RawWord] = []
    var location = 0
    while location < ns.length {
      var end = location
      while end < ns.length, !isSpace(ns.character(at: end)) { end += 1 }
      if end > location {
        let range = NSRange(location: location, length: end - location)
        if let selection = page.selection(for: range) {
          let b = selection.bounds(for: page)
          let rect = ScanRect(
            x: Double((b.minX - box.minX) / box.width), y: Double(1 - (b.maxY - box.minY) / box.height),
            width: Double(b.width / box.width), height: Double(b.height / box.height))
          words.append(RawWord(text: ns.substring(with: range), rect: rect, confidence: 1, exact: true))
        }
      }
      location = end + 1
    }
    return words.isEmpty ? nil : words
  }

  private static func isSpace(_ c: unichar) -> Bool {
    c == 32 || c == 10 || c == 13 || c == 9 || c == 0xA0
  }
}
