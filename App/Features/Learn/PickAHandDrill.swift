import Foundation
import MahjongCore

/// Pure logic of the Pick-a-Hand drill: a seeded 13-tile deal, the engine's ranking of the card's lines,
/// and whether the player's pick was among the closest three.
struct PickAHandDrill: Sendable, Equatable {
  struct RankedLine: Sendable, Equatable, Identifiable {
    let line: CardLine
    let distance: Int
    let possible: Bool
    var id: String { line.id }
    var name: String { line.displayName }
  }

  struct Outcome: Sendable, Equatable {
    let picked: RankedLine
    /// The three closest possible lines, best first.
    let top: [RankedLine]
    let isCorrect: Bool
    /// A coach sentence or two built from the analysis.
    let explanation: String
  }

  static let topCount = 3

  let seed: UInt64
  /// The 13 dealt tiles in display order.
  let hand: [Tile]

  init(seed: UInt64) {
    self.seed = seed
    self.hand = Wall.deal(seed: seed).hand.sortedForDisplay()
  }

  /// A wrong pick resets the streak; a right one extends it.
  static func updatedStreak(_ current: Int, correct: Bool) -> Int {
    correct ? current + 1 : 0
  }

  /// Scores `pickedLineID`. Nil when the card has no such line.
  ///
  /// The pick is right when it is one of the three closest lines, or exactly as close as the third
  /// (several lines often tie, and an equally close line is just as good a choice).
  func outcome(pickedLineID: String, analyzer: Analyzer) -> Outcome? {
    let results = analyzer.analyze(PlayerView(rack: hand))
    guard let pickedResult = results.first(where: { $0.line.id == pickedLineID }) else { return nil }
    let ranked = results.map {
      RankedLine(line: $0.line, distance: $0.best.distance, possible: $0.best.possible)
    }
    let top = Array(ranked.filter(\.possible).prefix(Self.topCount))
    let picked = RankedLine(
      line: pickedResult.line, distance: pickedResult.best.distance, possible: pickedResult.best.possible)

    var correct = top.contains { $0.id == picked.id }
    if !correct, picked.possible, top.count == Self.topCount, let third = top.last {
      correct = picked.distance <= third.distance
    }
    let explanation = Self.explanation(
      best: results.first(where: { $0.best.possible }), picked: picked, isCorrect: correct)
    return Outcome(picked: picked, top: top, isCorrect: correct, explanation: explanation)
  }

  private static func explanation(best: LineResult?, picked: RankedLine, isCorrect: Bool) -> String {
    guard let best else { return "None of the lines can be made from these tiles." }
    let held = best.best.usedRack.values.reduce(0, +)
    var text =
      "Your closest line is \(best.line.displayName) in \(best.line.section), \(awayText(best.best.distance)): \(held) of your 13 tiles already fit it."
    if best.best.distance <= 6 && !best.best.missing.isEmpty {
      let names = best.best.missing.prefix(3).map {
        $0.count > 1 ? "\($0.tile.name) ×\($0.count)" : $0.tile.name
      }
      text += " You still need " + names.joined(separator: ", ") + "."
    }
    guard picked.possible else {
      return text + " \(picked.name) cannot be made from this hand."
    }
    if picked.id == best.line.id {
      text += " You picked it, so you are aiming exactly where the tiles point."
    } else if isCorrect {
      text += " \(picked.name) is \(awayText(picked.distance)), about as close, so it is a good pick too."
    } else {
      let gap = max(0, picked.distance - best.best.distance)
      text +=
        " \(picked.name) is \(awayText(picked.distance)), \(gap) further away. Look for lines that use more of the tiles you already hold."
    }
    return text
  }
}
