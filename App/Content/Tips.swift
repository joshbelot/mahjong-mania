import Foundation
import MahjongCore

struct CoachTip: Sendable, Hashable, Identifiable {
  let id: String
  let text: String
}

/// Coach-level tips, shown one at a time.
enum Tips {
  static let all: [CoachTip] = [
    CoachTip(
      id: "keep-options",
      text: "Early on, keep two or three hands in mind. Commit after the Charleston."),
    CoachTip(
      id: "pairs-hard",
      text:
        "Pairs are hard to finish because jokers can't help with them. Favour hands where your pairs are already done."
    ),
    CoachTip(
      id: "singles-early",
      text: "Singles and Pairs hands must be decided early: no jokers and no calling."),
    CoachTip(
      id: "safe-discard",
      text: "A tile that three people have already discarded is probably safe to throw."),
    CoachTip(
      id: "watch-exposures",
      text: "Watch exposures. If someone shows a kong of 6 Dots, don't hand them a 6 Dot."),
    CoachTip(
      id: "jokers-gold",
      text:
        "Jokers are gold. You can't pass them, and you should almost never discard one."),
    CoachTip(
      id: "count-tiles",
      text: "There are only four of each ordinary tile. Count what you can see before you chase one."),
    CoachTip(
      id: "dead-hand",
      text:
        "If every copy of a tile you need is already out of play, that hand is dead. Switch early."),
    CoachTip(
      id: "joker-swap",
      text:
        "Look at exposures for jokers you can swap for. A matching natural tile gets you a joker."),
    CoachTip(
      id: "concealed-careful",
      text: "Concealed hands pay more, but one exposure ruins them. Don't call if you're going for C."),
    CoachTip(
      id: "blind-pass",
      text:
        "On the last pass you may pass blind. It's a gamble: you skip the chance to look, so only do it with tiles you don't want."
    ),
    CoachTip(
      id: "flowers-count",
      text: "All flowers are the same tile, so any flower you pick up helps every flower slot."),
    CoachTip(
      id: "soap-zero",
      text: "Soap pulls double duty: the zero in year hands and the White Dragon. Hold on to it."),
    CoachTip(
      id: "say-discard",
      text: "Say your discard out loud, clearly. Mistakes at the table are usually missed tiles."),
    CoachTip(
      id: "dragon-match",
      text:
        "A dragon in a suit's colour is the matching dragon: Red with Cracks, Green with Bams, Soap with Dots."
    ),
    CoachTip(
      id: "shift-lines",
      text:
        "Lines marked as any consecutive or like numbers can slide. Check every slide before you give up on them."
    ),
    CoachTip(
      id: "quints-jokers",
      text: "Quints need at least one joker, so count your jokers before you plan one."),
    CoachTip(
      id: "house-rules",
      text: "Agree on house rules before the first hand. It prevents arguments later."),
  ]

  /// Returns a tip not in `shownIDs`, chosen deterministically from `seed`, or nil when every tip
  /// has been shown.
  static func next(after shownIDs: Set<String>, seed: UInt64) -> CoachTip? {
    let remaining = all.filter { !shownIDs.contains($0.id) }
    guard !remaining.isEmpty else { return nil }
    var rng = SeededRandom(seed: seed)
    let index = Int(rng.next() % UInt64(remaining.count))
    return remaining[index]
  }
}
