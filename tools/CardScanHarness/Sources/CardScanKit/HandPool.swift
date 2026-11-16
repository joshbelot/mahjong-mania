import Foundation
import MahjongCore

/// How a hand's number rule is printed on the page.
public enum ShiftScope: String, Codable {
  case none
  /// Any consecutive/like numbers; printed in a section titled for it (section scope) or marked `*`.
  case consecutive
  /// Keep odd/even; printed with `**`.
  case parity
}

public struct PoolHand {
  public var source: String  // card-file line, e.g. "FF 2026/x 2222/y 6666/y ; 25 ; X"
  public var shift: ShiftScope
  public var line: CardLine
}

/// Original hands for the corpus. Generated from templates and validated with the app's own parser, so every
/// hand is a legal 14-tile line. None of them is copied from a published card.
public enum HandPool {
  static let points = [25, 25, 25, 30, 30, 35, 40, 45, 50, 75]
  static let suits = ["x", "y", "z"]

  public static func generate(count: Int, seed: UInt64, excluding used: inout Set<String>) -> [PoolHand] {
    var rng = SeededRng(seed: seed)
    var out: [PoolHand] = []
    var attempts = 0
    while out.count < count && attempts < count * 400 {
      attempts += 1
      guard let (body, shift) = candidate(&rng) else { continue }
      let concealed = rng.chance(0.3)
      let source = "\(body) ; \(rng.pick(points)) ; \(concealed ? "C" : "X")"
        + (shift == .none ? "" : " ;  ; " + (shift == .consecutive ? "shift" : "shift2"))
      guard case .success(let line) = Notation.parseLine(source) else { continue }
      let key = ScanSemantics.key(line)
      if used.contains(key) { continue }
      used.insert(key)
      out.append(PoolHand(source: source, shift: shift, line: line))
    }
    return out
  }

  private static func candidate(_ rng: inout SeededRng) -> (String, ShiftScope)? {
    switch rng.int(0...9) {
    case 0, 1, 2: return (numberHand(&rng), .none)
    case 3: return (windDragonHand(&rng), .none)
    case 4: return (arithmeticHand(&rng), .none)
    case 5: return (soapYearHand(&rng), .none)
    case 6: return (runHand(&rng), .consecutive)
    case 7: return (likeHand(&rng), .consecutive)
    case 8: return (parityHand(&rng), .parity)
    default: return (windAlternativeHand(&rng), .none)
    }
  }

  private static func flowers(_ n: Int) -> String { String(repeating: "F", count: n) }

  private static func split(_ total: Int, parts: Int, _ rng: inout SeededRng) -> [Int]? {
    var sizes = Array(repeating: 2, count: parts)
    var left = total - 2 * parts
    if left < 0 { return nil }
    while left > 0 {
      let i = rng.int(0...(parts - 1))
      if sizes[i] < 5 { sizes[i] += 1; left -= 1 }
      if sizes.allSatisfy({ $0 >= 5 }) { break }
    }
    return left == 0 ? sizes : nil
  }

  private static func numberHand(_ rng: inout SeededRng) -> String {
    let f = rng.pick([0, 2, 2, 3, 4])
    let parts = rng.pick([3, 4, 4, 5])
    guard let sizes = split(14 - f, parts: parts, &rng) else { return "" }
    let varCount = rng.int(1...3)
    var groups = sizes.map { size -> String in
      String(repeating: String(rng.int(1...9)), count: size) + "/" + suits[rng.int(0...(varCount - 1))]
    }
    if rng.chance(0.25), let i = groups.indices.randomElement(using: &rng) {
      let size = sizes[i]
      groups[i] = String(repeating: "D", count: size) + "/" + suits[rng.int(0...(varCount - 1))]
    }
    return ([f > 0 ? flowers(f) : nil].compactMap { $0 } + groups).joined(separator: " ")
  }

  private static func windDragonHand(_ rng: inout SeededRng) -> String {
    var parts: [String] = []
    var total = 0
    if rng.chance(0.6) { parts.append("FF"); total += 2 }
    let winds = ["N", "E", "W", "S"].shuffled(using: &rng)
    for w in winds.prefix(rng.int(2...3)) {
      let n = rng.int(2...4)
      parts.append(String(repeating: w, count: n)); total += n
    }
    let dragons = ["R", "G", "0"].shuffled(using: &rng)
    for d in dragons.prefix(rng.int(0...2)) {
      let n = rng.int(2...3)
      parts.append(String(repeating: d, count: n)); total += n
    }
    var vars = suits.shuffled(using: &rng)
    while total < 14 {
      let n = min(14 - total, rng.pick([2, 4]))
      if n < 2 { return "" }
      parts.append(String(repeating: "D", count: n) + "/" + vars.removeFirst()); total += n
      if vars.isEmpty && total < 14 { return "" }
    }
    return total == 14 ? parts.joined(separator: " ") : ""
  }

  private static func arithmeticHand(_ rng: inout SeededRng) -> String {
    let a = rng.int(1...4)
    let b = rng.int(1...5)
    let c = a + b
    guard c <= 9 else { return "" }
    let size = rng.pick([3, 4])
    let vs = suits.shuffled(using: &rng)
    let f = 14 - 3 * size
    func g(_ n: Int, _ v: String) -> String { String(repeating: String(n), count: size) + "/" + v }
    return "\(f > 0 ? flowers(f) + " " : "")\(g(a, vs[0])) + \(g(b, vs[1])) = \(g(c, vs[2]))"
  }

  private static func soapYearHand(_ rng: inout SeededRng) -> String {
    let a = rng.int(1...9)
    let b = rng.int(1...9)
    let vs = suits.shuffled(using: &rng)
    let opts = [
      "FF \(a)0\(a)\(b)/\(vs[0]) \(a)\(a)\(a)\(a)/\(vs[1]) \(b)\(b)\(b)\(b)/\(vs[1])",
      "\(a)\(a)\(a)\(a)/\(vs[0]) 000 \(b)\(b)\(b)/\(vs[1]) \(a)\(a)\(a)\(a)/\(vs[2])",
      "FF NEWS \(a)0\(a)\(b)/\(vs[0]) \(b)0\(b)\(a)/\(vs[1])",
      "00 RR GG \(a)\(a)\(a)/\(vs[0]) \(b)\(b)\(b)\(b)/\(vs[1])",
    ]
    return rng.pick(opts)
  }

  private static func runHand(_ rng: inout SeededRng) -> String {
    let start = rng.int(1...4)
    let vs = suits.shuffled(using: &rng)
    let opts = [
      "FF \(start)\(start)/x \(start + 1)\(start + 1)\(start + 1)/x \(start + 2)\(start + 2)\(start + 2)\(start + 2)/x \(start + 3)\(start + 3)\(start + 3)/x",
      "FFF \(start)\(start)\(start)\(start)/\(vs[0]) \(start + 1)\(start + 1)\(start + 1)\(start + 1)/\(vs[1]) \(start + 2)\(start + 2)\(start + 2)/\(vs[2])",
      "\(start)\(start)\(start)/\(vs[0]) \(start + 1)\(start + 1)\(start + 1)\(start + 1)/\(vs[0]) \(start + 2)\(start + 2)\(start + 2)/\(vs[1]) \(start + 3)\(start + 3)\(start + 3)\(start + 3)/\(vs[1])",
    ]
    return rng.pick(opts)
  }

  private static func likeHand(_ rng: inout SeededRng) -> String {
    let n = rng.int(1...9)
    let vs = suits.shuffled(using: &rng)
    func g(_ size: Int, _ v: String) -> String { String(repeating: String(n), count: size) + "/" + v }
    let opts = [
      "FF \(g(4, vs[0])) \(g(2, vs[1])) \(g(4, vs[2])) DD/\(vs[0])",
      "\(g(4, vs[0])) \(g(4, vs[1])) \(g(3, vs[2])) FFF",
      "FF \(g(2, vs[0])) \(g(2, vs[1])) \(g(2, vs[2])) DD/\(vs[0]) DD/\(vs[1]) DD/\(vs[2])",
      "NN EE WW SS \(g(2, vs[0])) \(g(2, vs[1])) \(g(2, vs[2]))",
    ]
    return rng.pick(opts)
  }

  private static func parityHand(_ rng: inout SeededRng) -> String {
    let odd = rng.chance(0.5)
    let digits = odd ? [1, 3, 5, 7] : [2, 4, 6, 8]
    let vs = suits.shuffled(using: &rng)
    let a = digits[0], b = digits[1], c = digits[2], d = digits[3]
    func g(_ n: Int, _ size: Int, _ v: String) -> String { String(repeating: String(n), count: size) + "/" + v }
    let opts = [
      "\(g(a, 3, vs[0])) \(g(b, 4, vs[0])) \(g(c, 3, vs[0])) \(g(d, 4, vs[0]))",
      "FF \(g(a, 4, vs[0])) \(g(b, 2, vs[1])) \(g(c, 2, vs[1])) \(g(d, 4, vs[0]))",
      "FFFF \(g(a, 3, vs[0])) \(g(b, 3, vs[1])) \(g(c, 4, vs[2]))",
    ]
    return rng.pick(opts)
  }

  private static func windAlternativeHand(_ rng: inout SeededRng) -> String {
    let winds = ["N", "E", "W", "S"].shuffled(using: &rng)
    let pick = Array(winds.prefix(rng.int(2...3)))
    let dragons = rng.pick(["RRR GGG 000", "RR GG 00 FF", "RRR 000 GGG"])
    // base is 14: FF + dragons(9) + 3-wind pung
    let variants = pick.map { "FF \(dragons) \(String(repeating: $0, count: 3))" }
    return variants.joined(separator: " | ")
  }
}
