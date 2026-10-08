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
    changed()
    return true
  }

  func removeTile(at index: Int) {
    guard rack.indices.contains(index) else { return }
    rack.remove(at: index)
    changed()
  }

  func setRack(_ tiles: [Tile]) {
    rack = tiles
    changed()
  }

  func clearRack() {
    rack = []
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
    lastKey = nil
    lastResults = []
  }
}
