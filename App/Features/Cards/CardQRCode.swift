import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import MahjongCore
import UIKit

/// Sharing a card as a QR code (SPEC §17.7): the card file text is compressed and packed into a
/// `mahjongmania://card?v=1&d=…` link, which the system Camera opens in the app.
///
/// The data is the card file text in UTF-8, compressed with Foundation's zlib algorithm (raw DEFLATE)
/// and written as unpadded base64url. Everything happens on the phone; nothing is sent anywhere.
enum CardQRCode {
  static let scheme = "mahjongmania"
  static let host = "card"
  static let version = 1
  /// Longer links are not offered as a QR code: they scan badly.
  static let maxURLLength = 2000
  /// Links that arrive from outside (a pasted URL, another app) are refused above this length, and a card
  /// that unpacks to more than `maxCardBytes` is refused, so a crafted link cannot exhaust memory.
  static let maxIncomingLength = 20_000
  static let maxCardBytes = 500_000

  enum DecodeError: Error, Equatable {
    /// Not a link made by this app, or damaged.
    case notACard
    /// Made by a newer version of the app.
    case newerVersion

    var message: String {
      switch self {
      case .notACard: return "This QR code isn't a Mahjong Mania card, or it's damaged."
      case .newerVersion:
        return "This card was shared from a newer version of Mahjong Mania. Update the app to import it."
      }
    }
  }

  // MARK: Link

  /// The link for card file text, or nil when it is longer than `maxURLLength`.
  static func url(forCardText text: String) -> URL? {
    guard let compressed = try? (Data(text.utf8) as NSData).compressed(using: .zlib) as Data else { return nil }
    let encoded = base64URL(compressed)
    let string = "\(scheme)://\(host)?v=\(version)&d=\(encoded)"
    guard string.count <= maxURLLength else { return nil }
    return URL(string: string)
  }

  /// The card file text inside a link.
  static func cardText(from url: URL) throws -> String {
    guard url.absoluteString.count <= maxIncomingLength, url.scheme?.lowercased() == scheme,
      url.host?.lowercased() == host,
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let versionText = items.first(where: { $0.name == "v" })?.value, let linkVersion = Int(versionText)
    else { throw DecodeError.notACard }
    if linkVersion > version { throw DecodeError.newerVersion }
    guard linkVersion == version, let payload = items.first(where: { $0.name == "d" })?.value,
      let compressed = data(fromBase64URL: payload),
      let raw = try? (compressed as NSData).decompressed(using: .zlib) as Data,
      raw.count <= maxCardBytes, let text = String(data: raw, encoding: .utf8), !text.isEmpty
    else { throw DecodeError.notACard }
    return text
  }

  /// The card file text in a scanned string.
  static func cardText(from string: String) throws -> String {
    guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw DecodeError.notACard
    }
    return try cardText(from: url)
  }

  private static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func data(fromBase64URL string: String) -> Data? {
    var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 { base64.append("=") }
    return Data(base64Encoded: base64)
  }

  // MARK: What to put in the code for a card

  struct Plan: Equatable {
    var url: URL?
    /// The card had comments or other notes that were left out to make the code fit.
    var droppedComments = false

    var tooBig: Bool { url == nil }
  }

  /// Prefers the card's own text (comments included); if that is too long for a QR code, falls back
  /// to the compact form without comments; if that is still too long there is no code.
  static func plan(fullText: String?, card: Card) -> Plan {
    let compact = Notation.serialize(card)
    if let fullText, let url = url(forCardText: fullText) { return Plan(url: url) }
    if let url = url(forCardText: compact) {
      return Plan(url: url, droppedComments: fullText != nil && fullText != compact)
    }
    return Plan(url: nil)
  }

  // MARK: Pictures

  /// A QR code for `url`, always black on white with a quiet zone (so it scans in dark mode), error
  /// correction M, drawn at a whole number of pixels per module.
  static func image(for url: URL, minimumSide: CGFloat = 600) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(url.absoluteString.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let modules = Int(output.extent.width)
    guard modules > 0 else { return nil }
    let quiet = 4
    let scale = max(1, Int(ceil(minimumSide / CGFloat(modules + 2 * quiet))))
    let side = CGFloat((modules + 2 * quiet) * scale)
    let context = CIContext(options: [.useSoftwareRenderer: false])
    let scaled = output.samplingNearest().transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
      UIColor.white.setFill()
      renderer.fill(CGRect(origin: .zero, size: CGSize(width: side, height: side)))
      let origin = CGFloat(quiet * scale)
      renderer.cgContext.interpolationQuality = .none
      UIImage(cgImage: cgImage).draw(
        in: CGRect(x: origin, y: origin, width: CGFloat(modules * scale), height: CGFloat(modules * scale)))
    }
  }

  /// The text of every QR code found in a picture.
  static func detect(in image: UIImage) -> [String] {
    guard let ciImage = CIImage(image: image) ?? image.cgImage.map({ CIImage(cgImage: $0) }) else { return [] }
    let detector = CIDetector(
      ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    return (detector?.features(in: ciImage) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
  }
}
