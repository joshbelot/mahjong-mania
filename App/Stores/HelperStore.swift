import MahjongCore
import Observation
import SwiftUI

enum HelperMode: String, Codable, CaseIterable, Sendable {
  case charleston, playing, scout

  var title: String { rawValue.capitalized }
}

struct HelperDocument: VersionedDocument, Equatable {
  static let currentVersion = 1
  var version = HelperDocument.currentVersion
  var mode: HelperMode = .charleston
  var rack: [Tile] = []
  var exposures: [Exposure] = []
  /// Tile code → number seen elsewhere.
  var seen: [String: Int] = [:]
  var opponents: [OpponentInput] = HelperDocument.defaultOpponents
  var pinnedLineID: String?
  /// The Charleston header's "I'm East (dealer) · 14 tiles" switch.
  var isEast = false
  var charleston = CharlestonState()

  init() {}

  /// Every key is optional so files written by older versions keep loading when fields are added.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    mode = try c.decodeIfPresent(HelperMode.self, forKey: .mode) ?? .charleston
    rack = try c.decodeIfPresent([Tile].self, forKey: .rack) ?? []
    exposures = try c.decodeIfPresent([Exposure].self, forKey: .exposures) ?? []
    seen = try c.decodeIfPresent([String: Int].self, forKey: .seen) ?? [:]
    opponents = try c.decodeIfPresent([OpponentInput].self, forKey: .opponents) ?? Self.defaultOpponents
    pinnedLineID = try c.decodeIfPresent(String.self, forKey: .pinnedLineID)
    isEast = try c.decodeIfPresent(Bool.self, forKey: .isEast) ?? false
    charleston = try c.decodeIfPresent(CharlestonState.self, forKey: .charleston) ?? CharlestonState()
  }

  static let defaultOpponents = ["Right", "Across", "Left"].map { OpponentInput(label: $0, exposures: []) }
}

@MainActor
@Observable
final class HelperStore {
  private(set) var mode: HelperMode
  private(set) var rack: [Tile]
  private(set) var exposures: [Exposure]
  private(set) var seen: TileCounts
  private(set) var opponents: [OpponentInput]
  private(set) var pinnedLineID: String?
  private(set) var isEast: Bool
  private(set) var charleston: CharlestonState
  /// The pass order; the app sets it from the rule book (Phase 16).
  var sequence = CharlestonSequence.standard

  @ObservationIgnored private let persister: Persister<HelperDocument>
  @ObservationIgnored private var lastKey: AnalysisKey?
  @ObservationIgnored private var lastResults: [LineResult] = []
  /// How many times `analyze` actually ran (used by tests to prove memoisation).
  @ObservationIgnored private(set) var analysisCount = 0

  private struct AnalysisKey: Hashable {
    var cardID: String
    var cardUpdatedAt: Date
    var rack: [Tile]
    var exposures: [Exposure]
    var seen: TileCounts
  }

  init(directory: URL, persistDelay: Duration = .milliseconds(300)) {
    let file = JSONFileStore<HelperDocument>(directory: directory, name: "helper")
    let doc = file.load() ?? HelperDocument()
    mode = doc.mode
    rack = doc.rack
    exposures = doc.exposures
    seen = Self.counts(from: doc.seen)
    opponents = doc.opponents
    pinnedLineID = doc.pinnedLineID
    isEast = doc.isEast
    charleston = doc.charleston
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in self?.document }
  }

  private static func counts(from codes: [String: Int]) -> TileCounts {
    var result: TileCounts = [:]
    for (code, count) in codes {
      if let tile = Tile(code: code), count > 0 { result[tile] = count }
    }
    return result
  }

  private var document: HelperDocument {
    var doc = HelperDocument()
    doc.mode = mode
    doc.rack = rack
    doc.exposures = exposures
    doc.seen = Dictionary(uniqueKeysWithValues: seen.map { ($0.key.code, $0.value) })
    doc.opponents = opponents
    doc.pinnedLineID = pinnedLineID
    doc.isEast = isEast
    doc.charleston = charleston
    return doc
  }

  // MARK: Inputs

  /// Physical copies in use across the rack, exposures and seen tiles.
  var usage: TileCounts {
    var counts = rack.counts
    for exposure in exposures { for tile in exposure.tiles { counts[tile, default: 0] += 1 } }
    for (tile, count) in seen { counts[tile, default: 0] += count }
    return counts
  }

  var view: PlayerView { PlayerView(rack: rack, exposures: exposures) }

  func canAdd(_ tile: Tile) -> Bool { (usage[tile] ?? 0) < tile.copies }

  @discardableResult
  func add(_ tile: Tile) -> Bool {
    guard canAdd(tile) else { return false }
    rack.append(tile)
    noteAdded()
    changed()
    return true
  }

  func removeTile(at index: Int) {
    guard rack.indices.contains(index) else { return }
    let removed = rack.remove(at: index)
    noteRemoved(removed)
    changed()
  }

  /// Replacing the whole rack drops the locked suggestion; the pass number stays.
  func setRack(_ tiles: [Tile]) {
    rack = tiles
    charleston.locked = nil
    changed()
  }

  func clearRack() {
    rack = []
    charleston.locked = nil
    changed()
  }

  func addExposure(_ exposure: Exposure) {
    exposures.append(exposure)
    changed()
  }

  func removeExposure(at index: Int) {
    guard exposures.indices.contains(index) else { return }
    exposures.remove(at: index)
    changed()
  }

  func incrementSeen(_ tile: Tile) {
    guard canAdd(tile) else { return }
    seen[tile, default: 0] += 1
    changed()
  }

  func decrementSeen(_ tile: Tile) {
    guard let count = seen[tile], count > 0 else { return }
    if count == 1 { seen[tile] = nil } else { seen[tile] = count - 1 }
    changed()
  }

  func clearSeen() {
    seen = [:]
    changed()
  }

  func setMode(_ newMode: HelperMode) {
    mode = newMode
    changed()
  }

  func pin(lineID: String?) {
    pinnedLineID = lineID
    changed()
  }

  func addOpponentExposure(_ exposure: Exposure, at opponentIndex: Int) {
    guard opponents.indices.contains(opponentIndex) else { return }
    opponents[opponentIndex].exposures.append(exposure)
    changed()
  }

  func removeOpponentExposure(at exposureIndex: Int, opponentIndex: Int) {
    guard opponents.indices.contains(opponentIndex),
      opponents[opponentIndex].exposures.indices.contains(exposureIndex)
    else { return }
    opponents[opponentIndex].exposures.remove(at: exposureIndex)
    changed()
  }

  func clearOpponents() {
    opponents = HelperDocument.defaultOpponents
    changed()
  }

  // MARK: Charleston (SPEC §17.3)

  /// A full hand: 13 tiles, or 14 for East.
  var fullRackSize: Int { HelperRules.charlestonRackSize(isEast: isEast) }

  var steps: [CharlestonStep] { sequence.steps(skippingSecond: charleston.skipSecond) }

  /// The pass the table is on, or nil once the Charleston is finished.
  var currentStep: CharlestonStep? {
    steps.indices.contains(charleston.passIndex) ? steps[charleston.passIndex] : nil
  }

  var isCharlestonDone: Bool { currentStep == nil }

  /// "Pass 1 of 7 · Right"; the courtesy pass reads "Courtesy · Across · 0–3 tiles".
  var trackerText: String {
    guard let step = currentStep else { return "Charleston done" }
    if step.isCourtesy { return "Pass \(charleston.passIndex + 1) of \(steps.count) \u{00B7} Courtesy \u{00B7} \(step.direction) \u{00B7} 0\u{2013}3 tiles" }
    return "Pass \(charleston.passIndex + 1) of \(steps.count) \u{00B7} \(step.direction)"
  }

  /// "Stop after this Charleston" is offered during the first three passes, when there is
  /// something after them to skip to.
  var canStopAfterFirst: Bool {
    guard let step = currentStep, step.round == .first else { return false }
    return !charleston.skipSecond && (sequence.second || sequence.courtesy)
  }

  /// A suggestion can be locked once the rack is full and nothing is locked.
  var canLockSuggestion: Bool {
    mode == .charleston && !isCharlestonDone && charleston.locked == nil && rack.count >= fullRackSize
  }

  func setEast(_ east: Bool) {
    isEast = east
    changed()
  }

  /// Computes the 3 tiles to pass for the current rack and holds on to them.
  func lockSuggestion(using analyzer: Analyzer) {
    guard !isCharlestonDone, rack.count >= 3 else { return }
    let advice = analyzer.suggestPasses(view)
    charleston.locked = LockedPass(
      tiles: advice.passes.map(\.tile), reasons: advice.passes.map(\.reason),
      focus: advice.focusSections)
    changed()
  }

  /// Coach: lock automatically once the rack is full. Safe to call at any time.
  func lockSuggestionIfNeeded(using analyzer: Analyzer) {
    if canLockSuggestion { lockSuggestion(using: analyzer) }
  }

  func stopAfterFirstCharleston() {
    guard canStopAfterFirst else { return }
    charleston.skipSecond = true
    charleston.passIndex = min(charleston.passIndex, 2)
    charleston.locked = nil
    changed()
  }

  /// Back to pass 1; the rack stays.
  func restartCharleston() {
    charleston = CharlestonState()
    changed()
  }

  private func noteRemoved(_ tile: Tile) {
    guard mode == .charleston, charleston.locked != nil else { return }
    charleston.locked?.removedSinceLock.append(tile)
    advanceIfSwapped()
  }

  private func noteAdded() {
    guard mode == .charleston, charleston.locked != nil else { return }
    charleston.locked?.addedSinceLock += 1
    advanceIfSwapped()
  }

  /// The lock ends and the tracker moves on only when the rack is full again and at least one tile
  /// was taken out and at least one put in since the lock.
  private func advanceIfSwapped() {
    guard let locked = charleston.locked, rack.count >= fullRackSize,
      !locked.removedSinceLock.isEmpty, locked.addedSinceLock > 0
    else { return }
    charleston.locked = nil
    charleston.passIndex = min(charleston.passIndex + 1, steps.count)
  }

  // MARK: Analysis (memoised on the last input)

  func results(using analyzer: Analyzer) -> [LineResult] {
    let key = AnalysisKey(
      cardID: analyzer.card.id, cardUpdatedAt: analyzer.card.updatedAt, rack: rack.sorted(),
      exposures: exposures, seen: seen)
    if key == lastKey { return lastResults }
    analysisCount += 1
    let results = analyzer.analyze(PlayerView(rack: rack, exposures: exposures), seen: seen)
    lastKey = key
    lastResults = results
    return results
  }

  private func changed() {
    persister.changed()
  }

  func flush() { persister.flush() }

  func reset() {
    persister.removeFile()
    mode = .charleston
    rack = []
    exposures = []
    seen = [:]
    opponents = HelperDocument.defaultOpponents
    pinnedLineID = nil
    isEast = false
    charleston = CharlestonState()
    lastKey = nil
    lastResults = []
  }
}
