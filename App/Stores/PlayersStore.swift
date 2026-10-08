import MahjongCore
import Observation
import SwiftUI

struct PlayersDocument: VersionedDocument, Equatable {
  static let currentVersion = 1
  var version = PlayersDocument.currentVersion
  var players: [Player] = []
}

@MainActor
@Observable
final class PlayersStore {
  private(set) var players: [Player]
  @ObservationIgnored private let persister: Persister<PlayersDocument>

  init(directory: URL, persistDelay: Duration = .milliseconds(300)) {
    let file = JSONFileStore<PlayersDocument>(directory: directory, name: "players")
    players = file.load()?.players ?? []
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in self.map { PlayersDocument(players: $0.players) } }
  }

  var activePlayers: [Player] { players.filter { !$0.archived } }
  var archivedPlayers: [Player] { players.filter(\.archived) }

  func player(id: String) -> Player? { players.first { $0.id == id } }

  /// Adds a player with the first palette colour not used by an active player.
  @discardableResult
  func add(name: String, id: String = UUID().uuidString, at date: Date = Date()) -> Player {
    let used = Set(activePlayers.map(\.colorIndex))
    let paletteCount = PlayerPalette.hexes.count
    let index = (0..<paletteCount).first { !used.contains($0) } ?? (players.count % paletteCount)
    let player = Player(
      id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorIndex: index, createdAt: date)
    players.append(player)
    persister.changed()
    return player
  }

  func rename(id: String, to name: String) {
    mutate(id) { $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  func setColor(id: String, index: Int) {
    mutate(id) { $0.colorIndex = index }
  }

  func setArchived(id: String, _ archived: Bool) {
    mutate(id) { $0.archived = archived }
  }

  private func mutate(_ id: String, _ change: (inout Player) -> Void) {
    guard let index = players.firstIndex(where: { $0.id == id }) else { return }
    change(&players[index])
    persister.changed()
  }

  func flush() { persister.flush() }

  func reset() {
    persister.removeFile()
    players = []
  }
}
