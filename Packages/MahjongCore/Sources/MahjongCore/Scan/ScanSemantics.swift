import Foundation

/// Canonical line semantics for scan evaluation (SPEC §4.1): all variants, groups with counts, suit
/// equality/inequality/fixed-suit constraints, dragon constraints, shift, points and concealed flag.
/// The name, section, id and the order of groups or variants are deliberately not part of the meaning.
public enum ScanSemantics {
  public static func key(_ line: CardLine) -> String {
    let variants = line.variants.map { canonicalVariant($0.groups) }.sorted()
    return "\(line.points)|\(line.concealed ? "C" : "X")|\(line.shift.rawValue)|"
      + variants.joined(separator: "|")
  }

  /// Rename suit variables in every possible order and keep the smallest description, so `2026/x 2222/y`
  /// and `2222/y 2026/x`, or the same hand written with `y` and `z`, compare equal.
  static func canonicalVariant(_ groups: [GroupSpec]) -> String {
    var used: [SuitVar] = []
    for group in groups {
      for variable in variables(in: group.tile) where !used.contains(variable) { used.append(variable) }
    }
    var best: String?
    for permutation in permutations(of: Array(0..<max(used.count, 1))) {
      var map: [SuitVar: Int] = [:]
      for (index, variable) in used.enumerated() { map[variable] = permutation[index] }
      let text = groups.map { describe($0, map) }.sorted().joined(separator: ",")
      if best == nil || text < best! { best = text }
    }
    return best ?? ""
  }

  private static func variables(in tile: TileSpec) -> [SuitVar] {
    switch tile {
    case .number(_, let ref), .matchingDragon(let ref):
      if case .variable(let variable) = ref { return [variable] }
      return []
    case .fixed: return []
    }
  }

  private static func ref(_ ref: SuitRef, _ map: [SuitVar: Int]) -> String {
    switch ref {
    case .variable(let variable): return "v\(map[variable] ?? 9)"
    case .fixed(let suit): return suit.rawValue
    }
  }

  private static func describe(_ group: GroupSpec, _ map: [SuitVar: Int]) -> String {
    let tile: String
    switch group.tile {
    case .number(let value, let suit): tile = "\(value)\(ref(suit, map))"
    case .matchingDragon(let suit): tile = "D\(ref(suit, map))"
    case .fixed(let fixed): tile = fixed.code
    }
    return "\(tile)x\(group.count)"
  }

  private static func permutations(of values: [Int]) -> [[Int]] {
    if values.count <= 1 { return [values] }
    var result: [[Int]] = []
    for (index, value) in values.enumerated() {
      var rest = values
      rest.remove(at: index)
      for tail in permutations(of: rest) { result.append([value] + tail) }
    }
    return result
  }

  /// A rough 0...1 similarity between two lines, used only to pair a wrong draft with the row it was
  /// meant for. It ignores suit names. Never used to decide that a draft is right.
  public static func similarity(_ a: CardLine, _ b: CardLine) -> Double {
    func bag(_ line: CardLine) -> [String: Int] {
      var counts: [String: Int] = [:]
      for variant in line.variants {
        for group in variant.groups {
          let tile: String
          switch group.tile {
          case .number(let value, _): tile = "\(value)"
          case .matchingDragon: tile = "D"
          case .fixed(let fixed): tile = fixed.code
          }
          counts["\(tile)x\(group.count)", default: 0] += 1
        }
      }
      return counts
    }
    let left = bag(a)
    let right = bag(b)
    var shared = 0
    var total = 0
    for key in Set(left.keys).union(right.keys) {
      shared += min(left[key] ?? 0, right[key] ?? 0)
      total += max(left[key] ?? 0, right[key] ?? 0)
    }
    let groups = total == 0 ? 0 : Double(shared) / Double(total)
    let points = a.points == b.points ? 0.15 : 0
    return min(1, groups * 0.85 + points)
  }
}
