import Foundation

/// A concrete choice of suits for the variables of a pattern variant, plus the number shift `k`.
public struct Binding: Hashable, Sendable {
  public var x: Suit?
  public var y: Suit?
  public var z: Suit?
  public var k: Int

  public init(x: Suit? = nil, y: Suit? = nil, z: Suit? = nil, k: Int = 0) {
    self.x = x
    self.y = y
    self.z = z
    self.k = k
  }

  public func suit(for variable: SuitVar) -> Suit? {
    switch variable {
    case .x: return x
    case .y: return y
    case .z: return z
    }
  }
}

/// Helpers shared by the parser (supply validation) and the engine (target expansion).
enum Instantiate {
  static func variables(in groups: [GroupSpec]) -> [SuitVar] {
    var used = Set<SuitVar>()
    for group in groups {
      switch group.tile {
      case .number(_, .variable(let v)), .matchingDragon(.variable(let v)): used.insert(v)
      default: break
      }
    }
    return SuitVar.allCases.filter { used.contains($0) }
  }

  static func fixedSuits(in groups: [GroupSpec]) -> Set<Suit> {
    var used = Set<Suit>()
    for group in groups {
      switch group.tile {
      case .number(_, .fixed(let s)), .matchingDragon(.fixed(let s)): used.insert(s)
      default: break
      }
    }
    return used
  }

  /// Every injective assignment of the variables to number suits not used as fixed suits (k = 0).
  static func assignments(variables: [SuitVar], excluding fixed: Set<Suit>) -> [Binding] {
    let available = Suit.allCases.filter { !fixed.contains($0) }
    var result: [Binding] = []

    func extend(_ index: Int, _ current: Binding, _ remaining: [Suit]) {
      if index == variables.count {
        result.append(current)
        return
      }
      for (position, suit) in remaining.enumerated() {
        var next = current
        switch variables[index] {
        case .x: next.x = suit
        case .y: next.y = suit
        case .z: next.z = suit
        }
        var rest = remaining
        rest.remove(at: position)
        extend(index + 1, next, rest)
      }
    }

    extend(0, Binding(), available)
    return result
  }

  static func resolve(_ spec: TileSpec, binding: Binding) -> Tile? {
    func suit(_ ref: SuitRef) -> Suit? {
      switch ref {
      case .fixed(let s): return s
      case .variable(let v): return binding.suit(for: v)
      }
    }
    switch spec {
    case .number(let value, let ref):
      guard let s = suit(ref) else { return nil }
      let shifted = value + binding.k
      guard (1...9).contains(shifted) else { return nil }
      return .number(shifted, s)
    case .matchingDragon(let ref):
      guard let s = suit(ref) else { return nil }
      return Tile.matchingDragon(s)
    case .fixed(let tile):
      return tile
    }
  }

  /// Digits 1–9 written in the groups (Soap never counts); these are what `shift` moves.
  static func digits(in groups: [GroupSpec]) -> [Int] {
    groups.compactMap {
      if case .number(let value, _) = $0.tile { return value }
      return nil
    }
  }

  /// The first tile for which the resolved groups need more copies than exist, or nil if the supply works.
  /// Rules (SPEC §10.1): plain need (groups of 1–2) may not exceed the copies, and the total need may not
  /// exceed the copies plus the 8 jokers.
  static func supplyViolation(_ resolved: [(tile: Tile, count: Int)]) -> Tile? {
    var plain: [Tile: Int] = [:]
    var total: [Tile: Int] = [:]
    var order: [Tile] = []
    for (tile, count) in resolved {
      if total[tile] == nil { order.append(tile) }
      total[tile, default: 0] += count
      if count < 3 { plain[tile, default: 0] += count }
    }
    for tile in order {
      if (plain[tile] ?? 0) > tile.copies || (total[tile] ?? 0) > tile.copies + 8 { return tile }
    }
    return nil
  }
}
