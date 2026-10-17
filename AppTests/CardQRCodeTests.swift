import Foundation
import MahjongCore
import Testing
import UIKit

@testable import MahjongMania

struct CardQRCodeTests {
  private var practiceText: String { Notation.serialize(PracticeCard.card) }

  @Test func practiceCardRoundTrips() throws {
    let url = try #require(CardQRCode.url(forCardText: practiceText))
    #expect(url.absoluteString.hasPrefix("mahjongmania://card?v=1&d="))
    #expect(url.absoluteString.count <= CardQRCode.maxURLLength)
    #expect(try CardQRCode.cardText(from: url) == practiceText)
    #expect(try CardQRCode.cardText(from: url.absoluteString) == practiceText)
  }

  @Test func aUserCardWithCommentsAndUnicodeRoundTrips() throws {
    let text = """
      ! Mah-jongg club \u{2014} Zo\u{00EB}'s card \u{1F004}
      !year 2026
      // Transcribed from the club handout; check the two year lines.
      # Ann\u{00E9}e
      FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs
      // a comment with unicode: \u{4E2D}\u{767C}\u{767D}
      FF 2222/x 4444/y 66/z 88/z ; 30 ; C ; Evens
      """
    let url = try #require(CardQRCode.url(forCardText: text))
    #expect(try CardQRCode.cardText(from: url) == text)
    // The decoded text imports as a card with both hands and the name.
    let report = CardImport.check(try CardQRCode.cardText(from: url))
    #expect(report.validCount == 2)
    #expect(report.name == "Mah-jongg club \u{2014} Zo\u{00EB}'s card \u{1F004}")
  }

  /// Random text does not compress, so it is the honest way to make something too big for a code.
  private func noise(words: Int) -> String {
    var generator = SystemRandomNumberGenerator()
    return (0..<words).map { _ in String(UInt64.random(in: 0...UInt64.max, using: &generator), radix: 36) }
      .joined(separator: " ")
  }

  @Test func aCardThatIsTooBigHasNoCode() {
    #expect(CardQRCode.url(forCardText: noise(words: 400)) == nil)
    // Even the compact form is too long (a huge card name does not compress).
    var card = PracticeCard.card
    card.name = noise(words: 400)
    let plan = CardQRCode.plan(fullText: Notation.serialize(card), card: card)
    #expect(plan.tooBig)
    #expect(plan.url == nil)
  }

  @Test func theCompactFormIsUsedWhenCommentsMakeItTooBig() throws {
    let card = PracticeCard.card
    let fat = Notation.serialize(card) + "\n// " + noise(words: 300)
    #expect(CardQRCode.url(forCardText: fat) == nil, "the notes alone push it over the limit")
    let plan = CardQRCode.plan(fullText: fat, card: card)
    let url = try #require(plan.url)
    #expect(plan.droppedComments)
    #expect(try CardQRCode.cardText(from: url) == Notation.serialize(card))
    #expect(CardQRCode.plan(fullText: Notation.serialize(card), card: card).droppedComments == false)
    #expect(CardQRCode.plan(fullText: nil, card: card).droppedComments == false)
  }

  @Test func badLinksAreRejected() throws {
    let good = try #require(CardQRCode.url(forCardText: practiceText)).absoluteString
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "https://example.com/card?v=1&d=abc") }
    #expect(throws: CardQRCode.DecodeError.notACard) {
      try CardQRCode.cardText(from: good.replacingOccurrences(of: "mahjongmania://", with: "otherapp://"))
    }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "mahjongmania://card?v=1&d=!!!not base64!!!") }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "mahjongmania://card?v=1&d=aGVsbG8") }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "mahjongmania://card?v=1") }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "mahjongmania://card?d=abc") }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "mahjongmania://deck?v=1&d=abc") }
    #expect(throws: CardQRCode.DecodeError.notACard) { try CardQRCode.cardText(from: "") }
  }

  @Test func aNewerVersionSaysSo() throws {
    let good = try #require(CardQRCode.url(forCardText: practiceText)).absoluteString
    let newer = good.replacingOccurrences(of: "v=1", with: "v=2")
    #expect(throws: CardQRCode.DecodeError.newerVersion) { try CardQRCode.cardText(from: newer) }
    #expect(CardQRCode.DecodeError.newerVersion.message.contains("Update the app"))
    #expect(CardQRCode.DecodeError.notACard.message == "This QR code isn't a Mahjong Mania card, or it's damaged.")
  }

  @Test func theCodeIsBlackOnWhiteAndScansBack() throws {
    let url = try #require(CardQRCode.url(forCardText: practiceText))
    let image = try #require(CardQRCode.image(for: url))
    #expect(image.size.width == image.size.height)
    #expect(image.size.width >= 600)
    let found = CardQRCode.detect(in: image)
    #expect(found == [url.absoluteString])
    #expect(try CardQRCode.cardText(from: found[0]) == practiceText)
    // The corner is the quiet zone: pure white.
    let cg = try #require(image.cgImage)
    let data = try #require(cg.dataProvider?.data)
    let bytes = CFDataGetBytePtr(data)!
    #expect(bytes[0] == 255 && bytes[1] == 255 && bytes[2] == 255)
  }

  @Test func aPictureWithoutACodeFindsNothing() {
    let blank = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
      UIColor.systemTeal.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
    }
    #expect(CardQRCode.detect(in: blank).isEmpty)
  }
}
