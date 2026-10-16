import Foundation
import MahjongCore

/// One pass of the Charleston, as shown by the pass tracker (SPEC §17.3).
struct CharlestonStep: Equatable, Sendable {
  enum Round: Sendable { case first, second, courtesy }

  var direction: String
  var round: Round

  var isCourtesy: Bool { round == .courtesy }
}

/// The order of the passes, from the rule book: first Charleston (right, across, left), then an
/// optional second (left, across, right), then an optional courtesy pass across.
struct CharlestonSequence: Equatable, Sendable {
  var second = true
  var courtesy = true

  static let standard = CharlestonSequence()

  func steps(skippingSecond: Bool = false) -> [CharlestonStep] {
    var steps = ["Right", "Across", "Left"].map { CharlestonStep(direction: $0, round: .first) }
    if second && !skippingSecond {
      steps += ["Left", "Across", "Right"].map { CharlestonStep(direction: $0, round: .second) }
    }
    if courtesy { steps.append(CharlestonStep(direction: "Across", round: .courtesy)) }
    return steps
  }
}

/// The three tiles suggested for the current pass. It stays put while the user swaps tiles.
struct LockedPass: Codable, Hashable, Sendable {
  /// The suggested tiles (instances; a tile may repeat).
  var tiles: [Tile]
  /// Why each tile was suggested, in the same order as `tiles`.
  var reasons: [String] = []
  /// The sections the hand is strongest in, shown under the list.
  var focus: [String] = []
  /// Tiles taken out of the rack since the lock, in order.
  var removedSinceLock: [Tile] = []
  /// Tiles put into the rack since the lock.
  var addedSinceLock = 0

  /// For each suggested tile, whether it has been taken out of the rack. Matches by tile: with two
  /// 7 Bams locked and one 7 Bam removed, exactly one row is ticked.
  var passed: [Bool] {
    var pool = removedSinceLock
    return tiles.map { tile in
      guard let index = pool.firstIndex(of: tile) else { return false }
      pool.remove(at: index)
      return true
    }
  }
}

struct CharlestonState: Codable, Hashable, Sendable {
  var passIndex = 0
  var locked: LockedPass?
  /// "Stop after this Charleston" was pressed: the second Charleston is skipped.
  var skipSecond = false

  init(passIndex: Int = 0, locked: LockedPass? = nil, skipSecond: Bool = false) {
    self.passIndex = passIndex
    self.locked = locked
    self.skipSecond = skipSecond
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    passIndex = try c.decodeIfPresent(Int.self, forKey: .passIndex) ?? 0
    locked = try c.decodeIfPresent(LockedPass.self, forKey: .locked)
    skipSecond = try c.decodeIfPresent(Bool.self, forKey: .skipSecond) ?? false
  }
}
