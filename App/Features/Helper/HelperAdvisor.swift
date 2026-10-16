import Foundation
import MahjongCore

/// Remembers the last pass advice, discard advice and scout report, so re-drawing the Helper (opening a
/// row, folding the keyboard) does not re-run the engine. Used only from the main actor, from `HelperView`.
final class HelperAdvisor {
  private struct Memo<Key: Hashable, Value> {
    var key: Key?
    var stored: Value?

    mutating func get(_ newKey: Key, make: () -> Value) -> (value: Value, ran: Bool) {
      if newKey == key, let stored { return (stored, false) }
      let made = make()
      key = newKey
      stored = made
      return (made, true)
    }
  }

  private struct HandKey: Hashable {
    var cardID: String
    var cardUpdatedAt: Date
    var rack: [Tile]
    var exposures: [Exposure]
  }

  private struct DiscardKey: Hashable {
    var hand: HandKey
    var seen: TileCounts
    var danger: [Tile: Double]
    var blanks: BlankPolicy?
  }

  private struct SwapKey: Hashable {
    var hand: HandKey
    var seen: TileCounts
    var blanks: BlankPolicy
  }

  private struct ScoutKey: Hashable {
    var cardID: String
    var cardUpdatedAt: Date
    var opponents: [OpponentInput]
    var seen: TileCounts
  }

  private var passMemo = Memo<HandKey, PassAdvice>()
  private var discardMemo = Memo<DiscardKey, [DiscardSuggestion]>()
  private var scoutMemo = Memo<ScoutKey, ScoutReport>()
  private var swapMemo = Memo<SwapKey, [BlankSwap]>()

  /// How many times the engine actually ran (used by tests to prove memoisation).
  private(set) var computations = 0

  init() {}

  private func handKey(_ analyzer: Analyzer, _ view: PlayerView) -> HandKey {
    HandKey(
      cardID: analyzer.card.id, cardUpdatedAt: analyzer.card.updatedAt, rack: view.rack.sorted(),
      exposures: view.exposures)
  }

  func passes(_ analyzer: Analyzer, view: PlayerView) -> PassAdvice {
    let result = passMemo.get(handKey(analyzer, view)) { analyzer.suggestPasses(view) }
    if result.ran { computations += 1 }
    return result.value
  }

  func discards(
    _ analyzer: Analyzer, view: PlayerView, seen: TileCounts, danger: [Tile: Double],
    blanks: BlankPolicy? = nil
  ) -> [DiscardSuggestion] {
    let key = DiscardKey(hand: handKey(analyzer, view), seen: seen, danger: danger, blanks: blanks)
    let result = discardMemo.get(key) {
      analyzer.suggestDiscards(view, seen: seen, danger: danger, blanks: blanks)
    }
    if result.ran { computations += 1 }
    return result.value
  }

  func blankSwaps(
    _ analyzer: Analyzer, view: PlayerView, seen: TileCounts, policy: BlankPolicy
  ) -> [BlankSwap] {
    let key = SwapKey(hand: handKey(analyzer, view), seen: seen, blanks: policy)
    let result = swapMemo.get(key) { analyzer.suggestBlankSwaps(view, seen: seen, policy: policy) }
    if result.ran { computations += 1 }
    return result.value
  }

  func scout(_ analyzer: Analyzer, opponents: [OpponentInput], seen: TileCounts) -> ScoutReport {
    let key = ScoutKey(
      cardID: analyzer.card.id, cardUpdatedAt: analyzer.card.updatedAt, opponents: opponents, seen: seen)
    let result = scoutMemo.get(key) { analyzer.scout(opponents: opponents, seen: seen) }
    if result.ran { computations += 1 }
    return result.value
  }
}
