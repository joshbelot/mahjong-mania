import Foundation

/// Immutable per-card analysis: targets are expanded once in `init`, then every `analyze` call evaluates them.
public final class Analyzer: Sendable {
  public let card: Card
  let lineTargets: [[Target]]

  public init(card: Card) {
    self.card = card
    self.lineTargets = card.lines.map { Engine.expand($0) }
  }

  /// All targets of the card, in line order.
  public var targets: [Target] { lineTargets.flatMap { $0 } }

  /// Every line with its best target, ranked: possible first → lower distance → fewer plain deficits →
  /// more live outs → higher points → card order.
  public func analyze(_ view: PlayerView, seen: TileCounts = [:]) -> [LineResult] {
    let context = EvalContext(view: view, live: Engine.liveCounts(view, seen: seen))
    return analyze(context: context)
  }

  func analyze(context: EvalContext) -> [LineResult] {
    struct Candidate {
      var lineIndex: Int
      var targetIndex: Int
      var core: EvalCore
      var possibleCount: Int
    }

    var candidates: [Candidate] = []
    for (lineIndex, line) in card.lines.enumerated() {
      var best: (index: Int, core: EvalCore)?
      var possibleCount = 0
      for (targetIndex, target) in lineTargets[lineIndex].enumerated() {
        let core = Engine.evaluateCore(target, concealed: line.concealed, context: context, detailed: false)
        if core.possible { possibleCount += 1 }
        if let current = best {
          if Engine.isBetter(core, than: current.core) { best = (targetIndex, core) }
        } else {
          best = (targetIndex, core)
        }
      }
      if let best {
        candidates.append(
          Candidate(lineIndex: lineIndex, targetIndex: best.index, core: best.core, possibleCount: possibleCount))
      }
    }

    candidates.sort { a, b in
      if Engine.isBetter(a.core, than: b.core) { return true }
      if Engine.isBetter(b.core, than: a.core) { return false }
      let pointsA = card.lines[a.lineIndex].points
      let pointsB = card.lines[b.lineIndex].points
      if pointsA != pointsB { return pointsA > pointsB }
      return a.lineIndex < b.lineIndex
    }

    return candidates.map { candidate in
      let line = card.lines[candidate.lineIndex]
      let target = lineTargets[candidate.lineIndex][candidate.targetIndex]
      let evaluation = Engine.evaluation(of: target, concealed: line.concealed, context: context)
      return LineResult(
        line: line, best: evaluation,
        alternatives: max(0, candidate.possibleCount - (evaluation.possible ? 1 : 0)))
    }
  }
}
