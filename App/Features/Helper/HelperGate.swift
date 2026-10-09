import Foundation
import MahjongCore

/// What the Helper shows at each assist level (SPEC §11.3). Pure, so the matrix can be unit-tested.
/// "Revealed" is the user's tap on a "Show closest hands" / "Suggest a pass" button: Peek shows the
/// content only after it, Coach shows it always, Off shows nothing.
struct HelperGate: Equatable, Sendable {
  static let peekHandCount = 3
  static let coachHandCount = 8

  let level: AssistLevel

  init(_ level: AssistLevel) {
    self.level = level
  }

  /// The Helper tab exists only when assist is not Off.
  var showsHelperTab: Bool { level != .off }

  /// Closest-hands list: Peek behind a button, Coach always open.
  func showsClosestHands(revealed: Bool) -> Bool {
    switch level {
    case .off: return false
    case .peek: return revealed
    case .coach: return true
    }
  }

  /// How many of `total` hands to list: Peek 3, Coach 8 (all with "Show all").
  func visibleHandCount(total: Int, showAll: Bool) -> Int {
    switch level {
    case .off: return 0
    case .peek: return min(total, Self.peekHandCount)
    case .coach: return showAll ? total : min(total, Self.coachHandCount)
    }
  }

  /// "Show all" is a Coach-only control, offered when more hands exist than the Coach limit.
  func offersShowAll(total: Int) -> Bool {
    level == .coach && total > Self.coachHandCount
  }

  /// Missing tiles under each hand without a tap (Coach). Peek shows them when a hand is tapped.
  var showsMissingInline: Bool { level == .coach }

  /// Tapping a hand opens its tile view with the missing tiles.
  var canExpandHands: Bool { level != .off }

  /// Pass and discard suggestions: Peek behind a button, Coach automatic.
  func showsSuggestions(revealed: Bool) -> Bool {
    switch level {
    case .off: return false
    case .peek: return revealed
    case .coach: return true
    }
  }

  /// "Can I call it?" is available at Peek and Coach.
  var offersCallCheck: Bool { level != .off }

  /// Coach adds a sentence explaining each verdict.
  var explainsCalls: Bool { level == .coach }

  /// Scout danger and safer tiles are available at Peek and Coach.
  var showsDanger: Bool { level != .off }

  /// Coach adds a "why" under each danger tile.
  var showsDangerReasons: Bool { level == .coach }

  /// Coach tips (`CoachTipBanner` also checks this itself).
  var showsTips: Bool { level == .coach }
}

/// Rack sizes for the Helper input.
enum HelperRules {
  /// A full hand on your turn.
  static let handSize = 14
  /// The usual size of a hand between turns, and when the keyboard folds away in the Charleston.
  static let restingHandSize = 13

  /// Most tiles the concealed rack may hold. Exposures count towards the 14 while playing; the
  /// Charleston can start with 14 (the dealer) so it allows 14.
  static func rackLimit(mode: HelperMode, exposedTiles: Int) -> Int {
    mode == .playing ? max(0, handSize - exposedTiles) : handSize
  }

  /// The count at which the keyboard collapses on its own.
  static func fullRackCount(mode: HelperMode, exposedTiles: Int) -> Int {
    mode == .playing ? max(1, handSize - exposedTiles) : restingHandSize
  }
}

/// Wording used by the Helper, kept free of SwiftUI so it can be tested.
enum HelperText {
  struct Segment: Equatable, Sendable {
    var text: String
    var bold: Bool
  }

  static let letItGo = "Let it go \u{2014} it doesn't help your top hands."
  static let callMahjong = "Call it \u{2014} that's Mahjong!"

  /// "Keep options open: you're strongest in **A** and **B**." as styled pieces.
  static func focusSegments(_ sections: [String]) -> [Segment] {
    guard !sections.isEmpty else { return [] }
    var segments = [Segment(text: "Keep options open: you're strongest in ", bold: false)]
    for (index, section) in sections.enumerated() {
      if index > 0 {
        segments.append(Segment(text: index == sections.count - 1 ? " and " : ", ", bold: false))
      }
      segments.append(Segment(text: section, bold: true))
    }
    segments.append(Segment(text: ".", bold: false))
    return segments
  }

  /// The name of an exposed group of this size.
  static func groupNoun(_ size: Int) -> String {
    switch size {
    case 3: return "pung"
    case 4: return "kong"
    case 5: return "quint"
    case 6: return "sextet"
    default: return "group of \(size)"
    }
  }

  /// "Expose a pung — you'd be 1 away".
  static func exposeHeadline(groupSize: Int, newDistance: Int) -> String {
    "Expose a \(groupNoun(groupSize)) \u{2014} you'd be \(newDistance) away"
  }

  /// "3 away" / "Mahjong!" for a result card.
  static func away(distance: Int) -> String {
    distance == 0 ? "Mahjong!" : "\(distance) away"
  }

  static func headline(for verdict: CallVerdict) -> String {
    switch verdict {
    case .mahjong: return callMahjong
    case .expose(_, let size, let distance): return exposeHeadline(groupSize: size, newDistance: distance)
    }
  }

  /// The Coach sentence under a verdict.
  static func explanation(for verdict: CallVerdict, tile: Tile) -> String {
    switch verdict {
    case .mahjong(let line):
      return "\(tile.name) completes \(line.displayName) (\(line.points) points). Say Mahjong and show your hand."
    case .expose(let line, let size, let distance):
      let tiles = "\(HelperText.groupNoun(size)) of \(tile.name)"
      let rest = distance == 1 ? "1 tile away" : "\(distance) tiles away"
      return "Calling it makes a \(tiles) for \(line.displayName), leaving you \(rest). It also puts those tiles on show."
    }
  }
}
