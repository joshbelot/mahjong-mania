import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

/// SPEC §19.4 step 2: random and hostile links never crash the QR decoder; they always end in an error.
struct CardQRFuzzTests {
  private func randomString(_ rng: inout SeededRandom, _ alphabet: [Character], max: Int) -> String {
    String((0..<Int(rng.next() % UInt64(max + 1))).map { _ in alphabet[Int(rng.next() % UInt64(alphabet.count))] })
  }

  @Test func tenThousandRandomStringsAreAlwaysAnError() {
    var rng = SeededRandom(seed: 0x9C0DE)
    let alphabet = Array("abcXYZ019-_=&?:/.% mahjongmania://card?v=1&d=\u{0}\u{1F600}\u{4E2D}")
    var accepted = 0
    for _ in 0..<10_000 {
      if (try? CardQRCode.cardText(from: randomString(&rng, alphabet, max: 80))) != nil { accepted += 1 }
    }
    #expect(accepted == 0)
  }

  @Test func tenThousandRandomPayloadsOnAValidLinkNeverCrash() {
    var rng = SeededRandom(seed: 0xBA5E64)
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=+/")
    for _ in 0..<10_000 {
      let payload = randomString(&rng, alphabet, max: 300)
      _ = try? CardQRCode.cardText(from: "mahjongmania://card?v=1&d=\(payload)")
    }
    for version in ["0", "2", "99", "-1", "x", ""] {
      _ = try? CardQRCode.cardText(from: "mahjongmania://card?v=\(version)&d=AAAA")
    }
  }

  @Test func aDecompressionBombIsRefusedQuicklyWithoutExhaustingMemory() throws {
    let big = Data(count: 80_000_000)  // 80 MB of zeros compresses to a few tens of KB
    let compressed = try (big as NSData).compressed(using: .zlib) as Data
    let payload = compressed.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    let link = "mahjongmania://card?v=1&d=\(payload)"
    let start = Date()
    #expect(throws: CardQRCode.DecodeError.self) { try CardQRCode.cardText(from: link) }
    #expect(Date().timeIntervalSince(start) < 2)
  }

  @Test func anEnormousLinkIsRefused() {
    let link = "mahjongmania://card?v=1&d=" + String(repeating: "A", count: 100_000)
    #expect(throws: CardQRCode.DecodeError.self) { try CardQRCode.cardText(from: link) }
  }
}
