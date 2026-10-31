import Foundation
import Testing

@testable import MahjongCore

/// SPEC §19.4 step 2: nothing a user can type or import may crash the parser; bad input always comes back
/// as an error with a message.
struct FuzzTests {
  private static let alphabet: [Character] = Array(
    "FF22446688NEWSRG0/xyzXCjJ;+=*#!-() \t\n\r" + "0123456789abcdefABCDEF" + "é日本😀\u{0}\u{200B}")

  private func random(_ rng: inout SeededRandom, maxLength: Int) -> String {
    let length = Int(rng.next() % UInt64(maxLength + 1))
    var result = ""
    for _ in 0..<length { result.append(Self.alphabet[Int(rng.next() % UInt64(Self.alphabet.count))]) }
    return result
  }

  /// A valid line with a few characters inserted, deleted or swapped.
  private func mutated(_ source: String, _ rng: inout SeededRandom) -> String {
    var chars = Array(source)
    for _ in 0..<Int(rng.next() % 4 + 1) where !chars.isEmpty {
      let at = Int(rng.next() % UInt64(chars.count))
      switch rng.next() % 3 {
      case 0: chars.remove(at: at)
      case 1: chars.insert(Self.alphabet[Int(rng.next() % UInt64(Self.alphabet.count))], at: at)
      default: chars[at] = Self.alphabet[Int(rng.next() % UInt64(Self.alphabet.count))]
      }
    }
    return String(chars)
  }

  @Test func tenThousandRandomLinesNeverCrashTheLineParser() {
    var rng = SeededRandom(seed: 0xF022)
    let sources = PracticeCard.card.lines.map(\.source)
    var failures = 0
    for i in 0..<10_000 {
      let text = i % 2 == 0 ? random(&rng, maxLength: 80) : mutated(sources[i % sources.count], &rng)
      switch Notation.parseLine(text) {
      case .success(let line):
        #expect(!line.variants.isEmpty)
      case .failure(let list):
        failures += 1
        #expect(!list.errors.isEmpty && list.errors.allSatisfy { !$0.message.isEmpty }, "\"\(text)\"")
      }
    }
    #expect(failures > 1_000, "the fuzzer should find plenty of invalid input")
  }

  @Test func tenThousandRandomFilesNeverCrashTheCardImport() {
    var rng = SeededRandom(seed: 0xF11E)
    for i in 0..<10_000 {
      var text = ""
      for _ in 0..<Int(rng.next() % 6) { text += random(&rng, maxLength: 60) + "\n" }
      if i % 5 == 0 { text = "!year \(rng.next() % 100_000)\n!name " + random(&rng, maxLength: 30) + "\n" + text }
      let result = Notation.parseCardFile(text)
      #expect(result.lines.count == result.sourceLineNumbers.count)
      #expect(result.errors.allSatisfy { !$0.errors.isEmpty })
    }
  }

  @Test func veryLongAndHostileInputIsHandled() {
    _ = Notation.parseLine(String(repeating: "2222/x ", count: 5_000))
    _ = Notation.parseLine(String(repeating: ";", count: 10_000))
    _ = Notation.parseCardFile(String(repeating: "FF 2222/x 4444/y 66/z ; 25 ; X ; A\n", count: 3_000))
    _ = Notation.parseCardFile(String(repeating: "\u{0}", count: 100_000))
  }
}
