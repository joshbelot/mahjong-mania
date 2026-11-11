import Foundation

/// Deterministic generator so the corpus is reproducible from a seed.
public struct SeededRng: RandomNumberGenerator {
  private var state: UInt64
  public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
  public mutating func next() -> UInt64 {
    state = state &+ 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
  public mutating func chance(_ p: Double) -> Bool { Double.random(in: 0..<1, using: &self) < p }
  public mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &self) }
  public mutating func pick<T>(_ items: [T]) -> T { items[Int.random(in: 0..<items.count, using: &self)] }
}
