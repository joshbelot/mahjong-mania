import Foundation

/// SplitMix64: a tiny deterministic generator, identical on every platform and toolchain.
public struct SeededRandom: RandomNumberGenerator, Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    state = seed
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

extension SeededRandom {
  /// Fisher–Yates shuffle driven only by `next()`, so the result for a seed never changes across
  /// platforms or Swift versions (the stdlib's `shuffled(using:)` makes no such promise).
  public static func shuffled<T>(_ items: [T], seed: UInt64) -> [T] {
    var rng = SeededRandom(seed: seed)
    var result = items
    var i = result.count - 1
    while i > 0 {
      let j = Int(rng.next() % UInt64(i + 1))
      result.swapAt(i, j)
      i -= 1
    }
    return result
  }
}
