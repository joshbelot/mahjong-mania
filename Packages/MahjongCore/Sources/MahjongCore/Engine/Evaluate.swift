import Foundation

private let tileTypeCount = 36
private let jokerIndex = Tile.joker.sortIndex

struct NormalizedExposure {
  var tile: Tile
  var count: Int
}

/// Everything about a player's view that is the same for every target; built once per analysis.
struct EvalContext {
  var rack = [Int](repeating: 0, count: tileTypeCount)
  var live = [Int](repeating: 0, count: tileTypeCount)
  var rackTiles: [Tile]
  var detectDead: Bool
  var exposures: [NormalizedExposure] = []
  var exposureInvalid = false
  var anyExposureJoker = false

  /// `live == nil` turns off dead-hand detection (the live vector then ignores seen tiles).
  init(view: PlayerView, live: TileCounts?) {
    detectDead = live != nil
    rackTiles = view.rack.sorted()
    for tile in view.rack { rack[tile.sortIndex] += 1 }
    let liveMap = live ?? Engine.liveCounts(view, seen: [:])
    for tile in Tile.allCases { self.live[tile.sortIndex] = liveMap[tile] ?? 0 }
    for exposure in view.exposures {
      let naturals = exposure.tiles.filter { $0 != .joker }
      if exposure.tiles.contains(.joker) { anyExposureJoker = true }
      if let first = naturals.first, naturals.allSatisfy({ $0 == first }) {
        exposures.append(NormalizedExposure(tile: first, count: exposure.tiles.count))
      } else {
        exposureInvalid = true
      }
    }
  }

  var hasExposures: Bool { !exposures.isEmpty || exposureInvalid }
}

struct EvalCore {
  var possible: Bool
  var reason: ImpossibleReason?
  var distance: Int
  var plainDeficit: Int
  var jokersUsed: Int
  var jokerlessPossible: Bool
  var liveOuts: Int
  var missing: [MissingTile] = []
  var usedRack: TileCounts = [:]
  var unusedRack: [Tile] = []
  var deadTiles: [Tile] = []
}

extension Engine {
  /// Distance of one target from the player's view (SPEC §10.2).
  public static func evaluate(
    _ target: Target, line: CardLine, view: PlayerView, live: TileCounts?
  ) -> Evaluation {
    let context = EvalContext(view: view, live: live)
    return evaluation(of: target, concealed: line.concealed, context: context)
  }

  static func evaluation(of target: Target, concealed: Bool, context: EvalContext) -> Evaluation {
    let core = evaluateCore(target, concealed: concealed, context: context, detailed: true)
    return Evaluation(
      target: target, possible: core.possible, impossibleReason: core.reason, distance: core.distance,
      missing: core.missing, usedRack: core.usedRack, unusedRack: core.unusedRack,
      jokersUsed: core.jokersUsed, jokerlessPossible: core.jokerlessPossible, deadTiles: core.deadTiles,
      liveOuts: core.liveOuts)
  }

  private static func impossible(
    _ reason: ImpossibleReason, target: Target, context: EvalContext, detailed: Bool
  ) -> EvalCore {
    let total = target.groups.reduce(0) { $0 + $1.count }
    var core = EvalCore(
      possible: false, reason: reason, distance: total, plainDeficit: total, jokersUsed: 0,
      jokerlessPossible: false, liveOuts: 0)
    if detailed { core.unusedRack = context.rackTiles }
    return core
  }

  /// The single evaluation routine. `detailed == false` skips building the lists and dictionaries, which
  /// is all that is needed to rank targets.
  static func evaluateCore(
    _ target: Target, concealed: Bool, context: EvalContext, detailed: Bool
  ) -> EvalCore {
    if concealed && context.hasExposures {
      return impossible(.concealed, target: target, context: context, detailed: detailed)
    }

    var needs = target.needs
    if context.hasExposures {
      if context.exposureInvalid {
        return impossible(.exposure, target: target, context: context, detailed: detailed)
      }
      var used = [Bool](repeating: false, count: target.groups.count)
      var reduction: [Int: Int] = [:]
      for exposure in context.exposures {
        var matched = false
        for (index, group) in target.groups.enumerated()
        where !used[index] && group.jokerOK && group.tile == exposure.tile && group.count == exposure.count {
          used[index] = true
          reduction[group.tile.sortIndex, default: 0] += group.count
          matched = true
          break
        }
        if !matched {
          return impossible(.exposure, target: target, context: context, detailed: detailed)
        }
      }
      for index in needs.indices { needs[index].jok -= reduction[needs[index].idx] ?? 0 }
    }

    var plainDeficit = 0
    var jokerDeficit = 0
    var deadMask: UInt64 = 0
    var outMask: UInt64 = 0
    var jokerlessOK = !context.anyExposureJoker
    var jokerNeeds: [(idx: Int, deficit: Int)] = []
    var usedNaturals: [Int] = detailed ? [Int](repeating: 0, count: tileTypeCount) : []
    var plainMissing: [MissingTile] = []

    for need in needs {
      let have = context.rack[need.idx]
      let usePlain = min(have, need.plain)
      let useJoker = min(have - usePlain, need.jok)
      let defPlain = need.plain - usePlain
      let defJoker = need.jok - useJoker
      plainDeficit += defPlain
      jokerDeficit += defJoker
      if defPlain > 0 {
        outMask |= 1 << UInt64(need.idx)
        if context.detectDead && defPlain > context.live[need.idx] { deadMask |= 1 << UInt64(need.idx) }
        if detailed { plainMissing.append(MissingTile(tile: need.tile, count: defPlain, jokerOK: false)) }
      }
      if defJoker > 0 { jokerNeeds.append((need.idx, defJoker)) }
      if jokerlessOK && need.plain + need.jok - have > context.live[need.idx] { jokerlessOK = false }
      if detailed { usedNaturals[need.idx] = usePlain + useJoker }
    }

    let rackJokers = context.rack[jokerIndex]
    let jokersUsed = min(rackJokers, jokerDeficit)
    let shortfall = jokerDeficit - jokersUsed
    let distance = plainDeficit + shortfall

    var dead = deadMask != 0
    if context.detectDead && !dead && shortfall > 0 {
      var obtainable = context.live[jokerIndex]
      for entry in jokerNeeds { obtainable += min(entry.deficit, context.live[entry.idx]) }
      if shortfall > obtainable { dead = true }
    }

    var missing = plainMissing
    if shortfall > 0 {
      // Jokers go to the hardest tiles (fewest live copies) first; the rest must be collected.
      let ordered = jokerNeeds.sorted {
        let a = context.live[$0.idx]
        let b = context.live[$1.idx]
        return a != b ? a < b : $0.idx < $1.idx
      }
      var jokersLeft = jokersUsed
      for entry in ordered {
        let covered = min(jokersLeft, entry.deficit)
        jokersLeft -= covered
        let short = entry.deficit - covered
        if short > 0 {
          outMask |= 1 << UInt64(entry.idx)
          if detailed { missing.append(MissingTile(tile: Tile.allCases[entry.idx], count: short, jokerOK: true)) }
        }
      }
    }

    var liveOuts = 0
    for index in 0..<tileTypeCount where outMask & (1 << UInt64(index)) != 0 {
      liveOuts += context.live[index]
    }
    if shortfall > 0 { liveOuts += context.live[jokerIndex] }

    var core = EvalCore(
      possible: !dead, reason: dead ? .dead : nil, distance: distance, plainDeficit: plainDeficit,
      jokersUsed: jokersUsed, jokerlessPossible: jokerlessOK, liveOuts: liveOuts)

    if detailed {
      missing.sort {
        $0.tile.sortIndex != $1.tile.sortIndex ? $0.tile.sortIndex < $1.tile.sortIndex : !$0.jokerOK && $1.jokerOK
      }
      core.missing = missing
      for need in needs where usedNaturals[need.idx] > 0 { core.usedRack[need.tile] = usedNaturals[need.idx] }
      if jokersUsed > 0 { core.usedRack[.joker] = jokersUsed }
      var unused: [Tile] = []
      for index in 0..<tileTypeCount {
        let used = index == jokerIndex ? jokersUsed : usedNaturals[index]
        let left = context.rack[index] - used
        if left > 0 { unused.append(contentsOf: Array(repeating: Tile.allCases[index], count: left)) }
      }
      core.unusedRack = unused
      if context.detectDead {
        core.deadTiles = (0..<tileTypeCount).filter { deadMask & (1 << UInt64($0)) != 0 }.map { Tile.allCases[$0] }
      }
    }
    return core
  }

  /// True when `a` ranks strictly ahead of `b`: possible first → lower distance → fewer plain deficits →
  /// more live outs.
  static func isBetter(_ a: EvalCore, than b: EvalCore) -> Bool {
    if a.possible != b.possible { return a.possible }
    if a.distance != b.distance { return a.distance < b.distance }
    if a.plainDeficit != b.plainDeficit { return a.plainDeficit < b.plainDeficit }
    return a.liveOuts > b.liveOuts
  }
}
