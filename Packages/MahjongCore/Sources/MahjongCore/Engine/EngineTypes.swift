import Foundation

/// A group of tiles shown face-up: the natural tile (all identical) plus any jokers standing in.
public struct Exposure: Hashable, Codable, Sendable {
  public var tiles: [Tile]

  public init(tiles: [Tile]) {
    self.tiles = tiles
  }
}

public struct PlayerView: Hashable, Sendable {
  public var rack: [Tile]
  public var exposures: [Exposure]

  public init(rack: [Tile] = [], exposures: [Exposure] = []) {
    self.rack = rack
    self.exposures = exposures
  }
}

public struct TargetGroup: Hashable, Sendable {
  public var tile: Tile
  public var count: Int
  public var jokerOK: Bool
  /// Index of the group in the variant (`PatternVariant.groups`).
  public var groupIndex: Int

  public init(tile: Tile, count: Int, jokerOK: Bool, groupIndex: Int) {
    self.tile = tile
    self.count = count
    self.jokerOK = jokerOK
    self.groupIndex = groupIndex
  }
}

/// One fully concrete hand: a variant of a line with suits and number shift resolved.
public struct Target: Hashable, Sendable {
  public let lineID: String
  public let variantIndex: Int
  public let binding: Binding
  public let groups: [TargetGroup]
  /// Per tile: sum of the counts of groups that cannot take jokers.
  public let plainNeed: TileCounts
  /// Per tile: sum of the counts of groups that can take jokers.
  public let jokerNeed: TileCounts
  public let hasJokerGroups: Bool
  /// Canonical multiset string used to dedupe equivalent targets within a line.
  public let signature: String
  /// Distinct tiles with their plain/joker-able totals, ordered by `Tile.sortIndex` (used by the evaluator).
  let needs: [Need]

  struct Need: Hashable, Sendable {
    var idx: Int
    var tile: Tile
    var plain: Int
    var jok: Int
  }

  public init(lineID: String, variantIndex: Int, binding: Binding, groups: [TargetGroup]) {
    var plain: TileCounts = [:]
    var jok: TileCounts = [:]
    for group in groups {
      if group.jokerOK {
        jok[group.tile, default: 0] += group.count
      } else {
        plain[group.tile, default: 0] += group.count
      }
    }
    var tiles = Set(plain.keys)
    tiles.formUnion(jok.keys)
    self.lineID = lineID
    self.variantIndex = variantIndex
    self.binding = binding
    self.groups = groups
    self.plainNeed = plain
    self.jokerNeed = jok
    self.hasJokerGroups = groups.contains { $0.jokerOK }
    self.signature = groups.map { "\($0.tile.code):\($0.count):\($0.jokerOK ? 1 : 0)" }.sorted()
      .joined(separator: ",")
    self.needs = tiles.sorted().map {
      Need(idx: $0.sortIndex, tile: $0, plain: plain[$0] ?? 0, jok: jok[$0] ?? 0)
    }
  }

  /// All tiles of the hand in group order (jokers not included).
  public var tiles: [Tile] {
    groups.flatMap { Array(repeating: $0.tile, count: $0.count) }
  }
}

public enum ImpossibleReason: String, Sendable {
  case concealed, exposure, dead
}

public struct MissingTile: Hashable, Sendable {
  public var tile: Tile
  public var count: Int
  public var jokerOK: Bool

  public init(tile: Tile, count: Int, jokerOK: Bool) {
    self.tile = tile
    self.count = count
    self.jokerOK = jokerOK
  }
}

public struct Evaluation: Hashable, Sendable {
  public var target: Target
  public var possible: Bool
  public var impossibleReason: ImpossibleReason?
  /// Tiles still needed (0 = Mahjong).
  public var distance: Int
  public var missing: [MissingTile]
  /// Rack tiles that contribute, including jokers.
  public var usedRack: TileCounts
  public var unusedRack: [Tile]
  public var jokersUsed: Int
  public var jokerlessPossible: Bool
  public var deadTiles: [Tile]
  public var liveOuts: Int
}

public struct LineResult: Sendable {
  public var line: CardLine
  public var best: Evaluation
  /// Other possible targets for this line.
  public var alternatives: Int
}

public struct PassSuggestion: Sendable {
  public var tile: Tile
  public var reason: String

  public init(tile: Tile, reason: String) {
    self.tile = tile
    self.reason = reason
  }
}

public struct FocusSection: Sendable {
  public var section: String
  public var lines: [String]

  public init(section: String, lines: [String]) {
    self.section = section
    self.lines = lines
  }
}

public struct PassAdvice: Sendable {
  public var passes: [PassSuggestion]
  public var focus: [FocusSection]
  public var focusSections: [String] { focus.map(\.section) }

  public init(passes: [PassSuggestion], focus: [FocusSection]) {
    self.passes = passes
    self.focus = focus
  }
}

public struct DiscardSuggestion: Sendable {
  public var tile: Tile
  public var resultingDistance: Int
  public var reason: String

  public init(tile: Tile, resultingDistance: Int, reason: String) {
    self.tile = tile
    self.resultingDistance = resultingDistance
    self.reason = reason
  }
}

public enum CallVerdict: Sendable {
  case mahjong(CardLine)
  case expose(CardLine, groupSize: Int, newDistance: Int)
}

public struct OpponentInput: Hashable, Codable, Sendable {
  public var label: String
  public var exposures: [Exposure]

  public init(label: String, exposures: [Exposure]) {
    self.label = label
    self.exposures = exposures
  }
}

public struct OpponentRead: Sendable {
  public var label: String
  public var lines: [CardLine]

  public init(label: String, lines: [CardLine]) {
    self.label = label
    self.lines = lines
  }
}

public struct ScoutReport: Sendable {
  public var perOpponent: [OpponentRead]
  /// 0...1 per tile.
  public var danger: [Tile: Double]
  public var safe: [Tile]

  public init(perOpponent: [OpponentRead], danger: [Tile: Double], safe: [Tile]) {
    self.perOpponent = perOpponent
    self.danger = danger
    self.safe = safe
  }
}

/// Free functions behind `Analyzer`, exposed for tests.
public enum Engine {}
