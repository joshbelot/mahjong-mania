import MahjongCore

/// Pure state behind Line detail: which concrete hand (variant, number shift, suit binding) is drawn as
/// tiles. "Try other suits" cycles the suit binding; the shift stepper moves the numbers.
struct LineDetailModel: Equatable {
  let line: CardLine
  let targets: [Target]
  private(set) var variantIndex: Int
  private(set) var k: Int
  private(set) var suitStep = 0

  init(line: CardLine) {
    self.line = line
    let targets = Engine.expand(line)
    self.targets = targets
    let startVariant = targets.first?.variantIndex ?? 0
    let hasUnshifted = targets.contains { $0.variantIndex == startVariant && $0.binding.k == 0 }
    variantIndex = startVariant
    k = hasUnshifted ? 0 : (targets.first?.binding.k ?? 0)
  }

  /// A: Dots, B: Cracks, C: Bams, as in SPEC §11.7. Variables a pattern does not use do not matter.
  static func isDefaultBinding(_ binding: SuitBinding) -> Bool {
    (binding.x ?? .dots) == .dots && (binding.y ?? .cracks) == .cracks && (binding.z ?? .bams) == .bams
  }

  /// Variants that can be drawn at all.
  var variantIndexes: [Int] {
    Array(Set(targets.map(\.variantIndex))).sorted()
  }

  /// The number shifts available for the current variant, ascending. `[0]` for lines that do not shift.
  var availableShifts: [Int] {
    let values = Set(targets.filter { $0.variantIndex == variantIndex }.map(\.binding.k))
    return values.isEmpty ? [0] : values.sorted()
  }

  var shiftStep: Int { line.shift == .parity ? 2 : 1 }

  /// Targets for the current variant and shift, with the default suits first.
  var candidates: [Target] {
    let matching = targets.filter { $0.variantIndex == variantIndex && $0.binding.k == k }
    return matching.filter { Self.isDefaultBinding($0.binding) }
      + matching.filter { !Self.isDefaultBinding($0.binding) }
  }

  var current: Target? {
    let list = candidates
    guard !list.isEmpty else { return nil }
    return list[suitStep % list.count]
  }

  var canTrySuits: Bool { candidates.count > 1 }

  mutating func nextSuits() {
    let count = candidates.count
    guard count > 1 else { return }
    suitStep = (suitStep + 1) % count
  }

  mutating func selectVariant(_ index: Int) {
    guard variantIndexes.contains(index) else { return }
    variantIndex = index
    suitStep = 0
    let shifts = availableShifts
    if !shifts.contains(k) { k = shifts.contains(0) ? 0 : (shifts.first ?? 0) }
  }

  /// Moves to the available shift nearest to `value`.
  mutating func setShift(_ value: Int) {
    let shifts = availableShifts
    guard let nearest = shifts.min(by: { abs($0 - value) < abs($1 - value) }) else { return }
    if nearest != k { suitStep = 0 }
    k = nearest
  }

  /// "A = Dots · B = Cracks" for the suit variables of the drawn variant.
  var suitLegend: String {
    guard let target = current, line.variants.indices.contains(target.variantIndex) else { return "" }
    var pieces: [String] = []
    let used = Set(
      line.variants[target.variantIndex].groups.compactMap { group -> SuitVar? in
        switch group.tile {
        case .number(_, .variable(let v)), .matchingDragon(.variable(let v)): return v
        default: return nil
        }
      })
    for variable in SuitVar.allCases where used.contains(variable) {
      guard let suit = target.binding.suit(for: variable) else { continue }
      pieces.append("\(variable.displayLetter) = \(Self.suitName(suit))")
    }
    return pieces.joined(separator: " \u{00B7} ")
  }

  static func suitName(_ suit: Suit) -> String {
    switch suit {
    case .cracks: return "Cracks"
    case .bams: return "Bams"
    case .dots: return "Dots"
    }
  }
}
