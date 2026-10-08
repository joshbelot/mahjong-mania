import MahjongCore

/// Which colour family a glyph is drawn in. The view maps these to `Theme` tokens.
enum PatternInk: Hashable, Sendable {
  case variable(SuitVar)
  case suit(Suit)
  case honor
  case flower
}

/// One group of a pattern, e.g. `2222/x` -> glyphs "2222", ink `.variable(.x)`.
struct PatternPart: Hashable, Sendable {
  /// Index in `PatternVariant.groups`.
  let groupIndex: Int
  let spec: GroupSpec
  let glyphs: String
  let ink: PatternInk
  /// Subscript shown after the glyphs (A/B/C) when suit letters are on; nil otherwise.
  let suitLetter: String?
}

enum PatternItem: Hashable, Sendable {
  /// Groups that came from one body of the source (e.g. `2026/x`), drawn close together.
  case body([PatternPart])
  /// A decorative operator: "+", "=", "-" or "x".
  case op(String)
}

/// How one tile of a resolved pattern is shown in tile mode.
struct PatternSlot: Hashable, Sendable {
  enum Kind: Hashable, Sendable {
    /// The player has this tile (or it is simply drawn, when there is no evaluation).
    case natural
    /// A joker standing in for `tile`.
    case joker
    /// Still needed.
    case missing
  }

  let tile: Tile
  let kind: Kind
}

/// Pure grouping and colouring logic behind `HandPatternView`.
///
/// Tokens of one body (`2026/x`, `NEWS`, `112233/x`) have adjacent `range`s in the variant source; tokens
/// of different bodies are separated by at least one space or by an operator.
struct PatternLayout: Hashable, Sendable {
  let items: [PatternItem]

  init(variant: PatternVariant, showSuitLetters: Bool = false) {
    var items: [PatternItem] = []
    var body: [PatternPart] = []
    var previousEnd: Int?
    var groupIndex = 0

    func flush() {
      guard !body.isEmpty else { return }
      items.append(.body(Self.applyingSuitLetters(body, enabled: showSuitLetters)))
      body = []
    }

    for token in variant.tokens {
      switch token {
      case .op(let text, _):
        flush()
        previousEnd = nil
        items.append(.op(text))
      case .group(let spec, let range):
        if let end = previousEnd, end != range.lowerBound { flush() }
        body.append(
          PatternPart(
            groupIndex: groupIndex, spec: spec, glyphs: Self.glyphs(for: spec),
            ink: Self.ink(for: spec), suitLetter: nil))
        previousEnd = range.upperBound
        groupIndex += 1
      }
    }
    flush()
    self.items = items
  }

  /// Every part of every body, in order.
  var parts: [PatternPart] {
    items.flatMap { item -> [PatternPart] in
      if case .body(let parts) = item { return parts }
      return []
    }
  }

  // MARK: Glyphs and ink

  static func glyphs(for spec: GroupSpec) -> String {
    let character: String
    switch spec.tile {
    case .number(let value, _): character = String(value)
    case .matchingDragon: character = "D"
    case .fixed(let tile): character = tile.code
    }
    return String(repeating: character, count: spec.count)
  }

  static func ink(for spec: GroupSpec) -> PatternInk {
    switch spec.tile {
    case .number(_, let ref), .matchingDragon(let ref):
      switch ref {
      case .variable(let variable): return .variable(variable)
      case .fixed(let suit): return .suit(suit)
      }
    case .fixed(let tile):
      if case .flower = tile { return .flower }
      return .honor
    }
  }

  /// The suit variable of a spec, if it has one.
  static func suitVariable(of spec: GroupSpec) -> SuitVar? {
    switch spec.tile {
    case .number(_, .variable(let variable)), .matchingDragon(.variable(let variable)): return variable
    default: return nil
    }
  }

  /// Puts the A/B/C subscript on the last part of each suit variable within a body.
  private static func applyingSuitLetters(_ body: [PatternPart], enabled: Bool) -> [PatternPart] {
    guard enabled else { return body }
    var lastIndex: [SuitVar: Int] = [:]
    for (index, part) in body.enumerated() {
      if let variable = suitVariable(of: part.spec) { lastIndex[variable] = index }
    }
    return body.enumerated().map { index, part in
      guard let variable = suitVariable(of: part.spec), lastIndex[variable] == index else { return part }
      return PatternPart(
        groupIndex: part.groupIndex, spec: part.spec, glyphs: part.glyphs, ink: part.ink,
        suitLetter: variable.displayLetter)
    }
  }

  // MARK: Tile mode

  /// A concrete tile for a spec when there is no evaluation: x = Cracks, y = Bams, z = Dots.
  static func exampleTile(for spec: TileSpec) -> Tile {
    func suit(_ ref: SuitRef) -> Suit {
      switch ref {
      case .fixed(let suit): return suit
      case .variable(let variable):
        switch variable {
        case .x: return .cracks
        case .y: return .bams
        case .z: return .dots
        }
      }
    }
    switch spec {
    case .number(let value, let ref): return .number(value, suit(ref))
    case .matchingDragon(let ref): return Tile.matchingDragon(suit(ref))
    case .fixed(let tile): return tile
    }
  }

  /// Decides, for every slot of every group of a resolved target, whether the player has the tile, a joker
  /// stands in for it, or it is still missing. The result is aligned with `groups`.
  ///
  /// - Parameters:
  ///   - groups: the target's groups.
  ///   - missing: `Evaluation.missing`.
  ///   - naturalsHeld: natural tiles from the rack that the hand uses (`Evaluation.usedRack` without jokers).
  ///   - jokersUsed: `Evaluation.jokersUsed`.
  static func slots(
    groups: [TargetGroup], missing: [MissingTile], naturalsHeld: TileCounts, jokersUsed: Int
  ) -> [[PatternSlot]] {
    struct Budget {
      var plainNatural = 0
      var plainMissing = 0
      var jokerNatural = 0
      var jokerJoker = 0
      var jokerMissing = 0
    }

    var budgets: [Tile: Budget] = [:]
    var jokersLeft = jokersUsed
    for tile in Set(groups.map(\.tile)).sorted() {
      let plainSlots = groups.filter { $0.tile == tile && !$0.jokerOK }.reduce(0) { $0 + $1.count }
      let jokerSlots = groups.filter { $0.tile == tile && $0.jokerOK }.reduce(0) { $0 + $1.count }
      let missingPlain = missing.filter { $0.tile == tile && !$0.jokerOK }.reduce(0) { $0 + $1.count }
      let missingJoker = missing.filter { $0.tile == tile && $0.jokerOK }.reduce(0) { $0 + $1.count }
      let held = naturalsHeld[tile] ?? 0

      var budget = Budget()
      budget.plainMissing = min(plainSlots, missingPlain)
      budget.plainNatural = plainSlots - budget.plainMissing
      let heldForJokerGroups = max(0, held - budget.plainNatural)
      budget.jokerNatural = min(jokerSlots, heldForJokerGroups)
      budget.jokerMissing = min(jokerSlots - budget.jokerNatural, missingJoker)
      let leftover = jokerSlots - budget.jokerNatural - budget.jokerMissing
      budget.jokerJoker = min(leftover, jokersLeft)
      jokersLeft -= budget.jokerJoker
      // Anything unaccounted for (e.g. an exposed group) counts as held.
      budget.jokerNatural += leftover - budget.jokerJoker
      budgets[tile] = budget
    }

    return groups.map { group in
      var budget = budgets[group.tile] ?? Budget()
      var result: [PatternSlot] = []
      for _ in 0..<max(0, group.count) {
        if group.jokerOK {
          if budget.jokerNatural > 0 {
            budget.jokerNatural -= 1
            result.append(PatternSlot(tile: group.tile, kind: .natural))
          } else if budget.jokerJoker > 0 {
            budget.jokerJoker -= 1
            result.append(PatternSlot(tile: group.tile, kind: .joker))
          } else {
            budget.jokerMissing -= 1
            result.append(PatternSlot(tile: group.tile, kind: .missing))
          }
        } else if budget.plainNatural > 0 {
          budget.plainNatural -= 1
          result.append(PatternSlot(tile: group.tile, kind: .natural))
        } else {
          budget.plainMissing -= 1
          result.append(PatternSlot(tile: group.tile, kind: .missing))
        }
      }
      budgets[group.tile] = budget
      return result
    }
  }
}
