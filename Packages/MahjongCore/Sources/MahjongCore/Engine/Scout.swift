import Foundation

extension Analyzer {
  /// Reads opponents' exposures (SPEC §10.6): which lines they could be going for, and which tiles are
  /// dangerous to discard. Concealed lines are excluded. With no exposures anywhere the report is empty.
  public func scout(opponents: [OpponentInput], seen: TileCounts = [:]) -> ScoutReport {
    let active = opponents.filter { !$0.exposures.isEmpty }
    guard !active.isEmpty else { return ScoutReport(perOpponent: [], danger: [:], safe: []) }

    var reads: [OpponentRead] = []
    var maxDanger: [Tile: Double] = [:]

    for opponent in active {
      let context = EvalContext(view: PlayerView(rack: [], exposures: opponent.exposures), live: nil)
      var consistent: [(lineIndex: Int, target: Target)] = []
      for (lineIndex, line) in card.lines.enumerated() where !line.concealed {
        for target in lineTargets[lineIndex] {
          let core = Engine.evaluateCore(target, concealed: false, context: context, detailed: false)
          if core.possible { consistent.append((lineIndex, target)) }
        }
      }

      var lineIndexes: [Int] = []
      var seenLines = Set<Int>()
      for entry in consistent where seenLines.insert(entry.lineIndex).inserted { lineIndexes.append(entry.lineIndex) }
      reads.append(OpponentRead(label: opponent.label, lines: lineIndexes.map { card.lines[$0] }))

      guard !consistent.isEmpty else { continue }
      let share = 1.0 / Double(consistent.count)
      var danger: [Tile: Double] = [:]
      for entry in consistent {
        for group in Engine.unmatchedGroups(of: entry.target, exposures: context.exposures) {
          danger[group.tile, default: 0] += share
        }
      }
      for (tile, value) in danger { maxDanger[tile] = max(maxDanger[tile] ?? 0, value) }
    }

    // A tile whose every copy is already visible can't be what anyone is waiting for.
    var visible = seen
    for opponent in active {
      for exposure in opponent.exposures { for tile in exposure.tiles { visible[tile, default: 0] += 1 } }
    }
    for (tile, count) in visible where count >= tile.copies { maxDanger[tile] = 0 }

    let peak = maxDanger.values.max() ?? 0
    var danger: [Tile: Double] = [:]
    if peak > 0 {
      for (tile, value) in maxDanger where value > 0 { danger[tile] = value / peak }
    }
    let safe = Tile.allCases.filter { $0 != .joker && (danger[$0] ?? 0) == 0 }
    return ScoutReport(perOpponent: reads, danger: danger, safe: safe)
  }
}

extension Engine {
  /// The target's groups that are not completed by the (already validated) exposures.
  static func unmatchedGroups(of target: Target, exposures: [NormalizedExposure]) -> [TargetGroup] {
    var used = [Bool](repeating: false, count: target.groups.count)
    for exposure in exposures {
      for (index, group) in target.groups.enumerated()
      where !used[index] && group.jokerOK && group.tile == exposure.tile && group.count == exposure.count {
        used[index] = true
        break
      }
    }
    return target.groups.enumerated().filter { !used[$0.offset] }.map(\.element)
  }
}
