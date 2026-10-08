import Foundation

extension Engine {
  /// Every concrete hand a line can make: variants × suit assignments × number shifts (SPEC §10.1).
  /// Targets that need more copies of a tile than exist are dropped, and equivalent ones are deduped.
  public static func expand(_ line: CardLine) -> [Target] {
    var digits: [Int] = []
    for variant in line.variants { digits.append(contentsOf: Instantiate.digits(in: variant.groups)) }

    var shifts = [0]
    if line.shift != .none, let low = digits.min(), let high = digits.max() {
      shifts = Array((1 - low)...(9 - high)).filter { line.shift == .consecutive || $0 % 2 == 0 }
      shifts.sort { abs($0) != abs($1) ? abs($0) < abs($1) : $0 < $1 }
    }

    var targets: [Target] = []
    var seen = Set<String>()
    for (variantIndex, variant) in line.variants.enumerated() {
      let groups = variant.groups
      let variables = Instantiate.variables(in: groups)
      let fixed = Instantiate.fixedSuits(in: groups)
      let assignments = Instantiate.assignments(variables: variables, excluding: fixed)
      for k in shifts {
        for assignment in assignments {
          var binding = assignment
          binding.k = k
          var targetGroups: [TargetGroup] = []
          var valid = true
          for (index, group) in groups.enumerated() {
            guard let tile = Instantiate.resolve(group.tile, binding: binding) else {
              valid = false
              break
            }
            targetGroups.append(
              TargetGroup(tile: tile, count: group.count, jokerOK: group.count >= 3, groupIndex: index))
          }
          guard valid else { continue }
          if Instantiate.supplyViolation(targetGroups.map { ($0.tile, $0.count) }) != nil { continue }
          let target = Target(
            lineID: line.id, variantIndex: variantIndex, binding: binding, groups: targetGroups)
          if seen.insert(target.signature).inserted { targets.append(target) }
        }
      }
    }
    return targets
  }
}
