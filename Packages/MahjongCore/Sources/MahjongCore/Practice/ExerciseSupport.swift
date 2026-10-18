import Foundation

// MARK: Random helpers

extension SeededRandom {
  mutating func below(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }

  mutating func element<T>(of items: [T]) -> T? { items.isEmpty ? nil : items[below(items.count)] }

  mutating func shuffled<T>(_ items: [T]) -> [T] {
    var result = items
    var i = result.count - 1
    while i > 0 {
      result.swapAt(i, below(i + 1))
      i -= 1
    }
    return result
  }

  mutating func chance(_ percent: Int) -> Bool { below(100) < percent }

  mutating func int(in range: ClosedRange<Int>) -> Int { range.lowerBound + below(range.count) }
}

// MARK: Analyzer cache and single-line helpers

final class AnalyzerCache: @unchecked Sendable {
  static let shared = AnalyzerCache()
  private let lock = NSLock()
  private var entries: [(key: String, analyzer: Analyzer)] = []

  func analyzer(for card: Card) -> Analyzer {
    let key = card.id + "|" + String(card.lines.count) + "|"
      + String(card.lines.map(\.source).joined(separator: "\n").hashValue)
    lock.lock()
    defer { lock.unlock() }
    if let hit = entries.first(where: { $0.key == key }) { return hit.analyzer }
    let analyzer = Analyzer(card: card)
    entries.append((key, analyzer))
    if entries.count > 6 { entries.removeFirst() }
    return analyzer
  }
}

extension Analyzer {
  /// A shared analyzer for `card`, built once per card content (expanding a card's hands takes a moment).
  public static func cached(for card: Card) -> Analyzer { AnalyzerCache.shared.analyzer(for: card) }

  func lineIndex(of line: CardLine) -> Int? { card.lines.firstIndex { $0.id == line.id } }

  /// The closest target of one line for exactly these tiles (no dead-hand detection).
  func evaluation(at index: Int, tiles: [Tile]) -> Evaluation? {
    let line = card.lines[index]
    let context = EvalContext(view: PlayerView(rack: tiles), live: nil)
    var best: (target: Target, core: EvalCore)?
    for target in lineTargets[index] {
      let core = Engine.evaluateCore(target, concealed: line.concealed, context: context, detailed: false)
      if let current = best, !Engine.isBetter(core, than: current.core) { continue }
      best = (target, core)
    }
    return best.map { Engine.evaluation(of: $0.target, concealed: line.concealed, context: context) }
  }

  func distance(at index: Int, tiles: [Tile]) -> Int? { evaluation(at: index, tiles: tiles)?.distance }

  func matches(at index: Int, tiles: [Tile]) -> Bool {
    guard let evaluation = evaluation(at: index, tiles: tiles) else { return false }
    return evaluation.possible && evaluation.distance == 0
  }

  func targets(at index: Int) -> [Target] { lineTargets[index] }

  func randomTarget(at index: Int, rng: inout SeededRandom) -> Target? {
    rng.element(of: lineTargets[index])
  }

  /// Indexes of the lines that have at least one target.
  var usableLineIndexes: [Int] { card.lines.indices.filter { !lineTargets[$0].isEmpty } }
}

// MARK: Tile facts

enum TileKind: Hashable {
  case suit(Suit), wind, dragon, flower, joker
}

extension Tile {
  var kind: TileKind {
    switch self {
    case .number(_, let suit): return .suit(suit)
    case .wind: return .wind
    case .dragon: return .dragon
    case .flower: return .flower
    case .joker, .blank: return .joker
    }
  }

  var numberValue: Int? {
    if case .number(let value, _) = self { return value }
    return nil
  }

  var suitValue: Suit? {
    if case .number(_, let suit) = self { return suit }
    return nil
  }

  /// "Crack", "Bam", "Dot", "Wind", …: the family used in hints.
  var familyName: String {
    switch kind {
    case .suit(.cracks): return "Crack"
    case .suit(.bams): return "Bam"
    case .suit(.dots): return "Dot"
    case .wind: return "Wind"
    case .dragon: return "Dragon"
    case .flower: return "Flower"
    case .joker: return "Joker"
    }
  }

  /// One friendly sentence about the kind of tile, used in explanations.
  var teachingNote: String {
    switch self {
    case .number(_, .cracks): return "Cracks are the character suit, usually drawn in red."
    case .number(_, .bams): return "Bams are the bamboo suit, usually drawn in green. The 1 Bam is a bird."
    case .number(_, .dots): return "Dots are the circle suit, usually drawn in blue."
    case .wind: return "Winds are North, East, West and South, four of each."
    case .dragon(.red): return "The Red Dragon goes with the Cracks."
    case .dragon(.green): return "The Green Dragon goes with the Bams."
    case .dragon(.white): return "Soap, the White Dragon, goes with the Dots. It is also the zero in year hands."
    case .flower: return "All eight Flowers count as the same tile, whatever picture they show."
    case .joker: return "Jokers stand in for other tiles, but only in groups of three or more."
    case .blank: return "A blank is a spare tile with nothing on it."
    }
  }
}

extension Suit {
  var plainName: String {
    switch self {
    case .cracks: return "Cracks"
    case .bams: return "Bams"
    case .dots: return "Dots"
    }
  }
}

func groupNoun(_ count: Int) -> String {
  switch count {
  case 1: return "Single"
  case 2: return "Pair"
  case 3: return "Pung"
  case 4: return "Kong"
  case 5: return "Quint"
  case 6: return "Sextet"
  default: return "Set of \(count)"
  }
}

func awayText(_ distance: Int) -> String {
  distance == 1 ? "1 tile away" : "\(distance) tiles away"
}

/// "7 Bam ×2, Red Dragon" for the tiles an evaluation still needs.
func missingText(_ missing: [MissingTile], limit: Int = 4) -> String {
  missing.prefix(limit).map { $0.count > 1 ? "\($0.tile.name) ×\($0.count)" : $0.tile.name }
    .joined(separator: ", ")
}

// MARK: Building hands

extension Exercises {
  /// The tiles of a target as groups, with `jokers` standing in inside groups of three or more (at least
  /// two natural tiles are always kept in a group).
  static func groupTiles(of target: Target, jokers: Int, rng: inout SeededRandom) -> [[Tile]] {
    var groups = target.groups.map { Array(repeating: $0.tile, count: $0.count) }
    let capacity = target.groups.map { $0.jokerOK ? max(0, $0.count - 2) : 0 }
    var placed = [Int](repeating: 0, count: groups.count)
    var total = 0
    let order = rng.shuffled(Array(groups.indices))
    var progress = true
    while total < jokers && progress {
      progress = false
      for i in order where total < jokers && placed[i] < capacity[i] {
        groups[i][groups[i].count - 1 - placed[i]] = .joker
        placed[i] += 1
        total += 1
        progress = true
      }
    }
    return groups
  }

  /// `count` random tiles from the wall that can be added to `hand` without exceeding the supply.
  static func noiseTiles(_ count: Int, besides hand: [Tile], jokers: Bool, rng: inout SeededRandom) -> [Tile] {
    guard count > 0 else { return [] }
    var counts = hand.counts
    var result: [Tile] = []
    for tile in rng.shuffled(Wall.full()) where result.count < count {
      if tile == .joker && !jokers { continue }
      if counts[tile, default: 0] < tile.copies {
        counts[tile, default: 0] += 1
        result.append(tile)
      }
    }
    return result
  }

  struct StackedDeal {
    var lineIndex: Int
    var target: Target
    /// 13 tiles in display order.
    var hand: [Tile]
  }

  /// 13 tiles of which `keep` come from one random hand of the card and the rest are random.
  static func stackedDeal(
    _ analyzer: Analyzer, rng: inout SeededRandom, keep: Int, lineIndex: Int? = nil, jokers: Int = 0,
    noiseJokers: Bool = false
  ) -> StackedDeal? {
    let index: Int
    if let lineIndex {
      index = lineIndex
    } else if let chosen = rng.element(of: analyzer.usableLineIndexes) {
      index = chosen
    } else {
      return nil
    }
    guard let target = analyzer.randomTarget(at: index, rng: &rng) else { return nil }
    let all = rng.shuffled(groupTiles(of: target, jokers: jokers, rng: &rng).flatMap { $0 })
    let kept = Array(all.prefix(max(0, min(keep, 13))))
    let hand = kept + noiseTiles(13 - kept.count, besides: kept, jokers: noiseJokers, rng: &rng)
    return StackedDeal(lineIndex: index, target: target, hand: hand.sortedForDisplay())
  }
}

/// A generated exercise and whether it passed the deal filter for its type and difficulty.
struct Built {
  var exercise: Exercise
  var ok: Bool
}
