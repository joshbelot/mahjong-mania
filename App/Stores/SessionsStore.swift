import MahjongCore
import Observation
import SwiftUI

struct SessionsDocument: VersionedDocument, Equatable {
  static let currentVersion = 1
  var version = SessionsDocument.currentVersion
  var sessions: [Session] = []
  var activeSessionID: String?
}

@MainActor
@Observable
final class SessionsStore {
  private(set) var sessions: [Session]
  private(set) var activeSessionID: String?
  @ObservationIgnored private let persister: Persister<SessionsDocument>

  init(directory: URL, persistDelay: Duration = .milliseconds(300)) {
    let file = JSONFileStore<SessionsDocument>(directory: directory, name: "sessions")
    let loaded = file.load()
    sessions = loaded?.sessions ?? []
    activeSessionID = loaded?.activeSessionID
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in
      self.map { SessionsDocument(sessions: $0.sessions, activeSessionID: $0.activeSessionID) }
    }
  }

  var activeSession: Session? {
    guard let activeSessionID else { return nil }
    return sessions.first { $0.id == activeSessionID && $0.endedAt == nil }
  }

  /// Finished sessions, newest first.
  var finishedSessions: [Session] {
    sessions.filter { $0.endedAt != nil }.sorted { $0.createdAt > $1.createdAt }
  }

  func session(id: String) -> Session? { sessions.first { $0.id == id } }

  /// Starts a session (ending any session still in progress) and makes it the active one.
  @discardableResult
  func start(
    seatIDs: [String], startDealerIndex: Int = 0, cardID: String?, rules: RuleSet,
    id: String = UUID().uuidString, at date: Date = Date()
  ) -> Session {
    if let current = activeSession { end(sessionID: current.id, at: date) }
    let session = Session(
      id: id, createdAt: date, seatIDs: seatIDs, startDealerIndex: startDealerIndex, cardID: cardID,
      rules: rules)
    sessions.append(session)
    activeSessionID = id
    persister.changed()
    return session
  }

  func addHand(_ kind: HandKind, to sessionID: String, id: String = UUID().uuidString, at date: Date = Date()) {
    mutate(sessionID) { Scoring.adding(kind, to: $0, id: id, at: date) }
  }

  func editHand(id handID: String, to kind: HandKind, in sessionID: String) {
    mutate(sessionID) { Scoring.editing(handID: handID, to: kind, in: $0) }
  }

  func removeHand(id handID: String, from sessionID: String) {
    mutate(sessionID) { Scoring.removing(handID: handID, from: $0) }
  }

  func undoLast(in sessionID: String) {
    mutate(sessionID) { Scoring.undoingLast($0) }
  }

  func setRules(_ rules: RuleSet, in sessionID: String) {
    mutate(sessionID) { Scoring.withRules(rules, $0) }
  }

  func end(sessionID: String, at date: Date = Date()) {
    mutate(sessionID) { Scoring.ending($0, at: date) }
    if activeSessionID == sessionID { activeSessionID = nil }
    persister.changed()
  }

  /// Makes a finished session the active one again.
  func reopen(sessionID: String) {
    if let current = activeSession, current.id != sessionID { end(sessionID: current.id) }
    mutate(sessionID) { Scoring.reopening($0) }
    activeSessionID = sessionID
    persister.changed()
  }

  func delete(sessionID: String) {
    sessions.removeAll { $0.id == sessionID }
    if activeSessionID == sessionID { activeSessionID = nil }
    persister.changed()
  }

  private func mutate(_ sessionID: String, _ change: (Session) -> Session) {
    guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
    sessions[index] = change(sessions[index])
    persister.changed()
  }

  func flush() { persister.flush() }

  func reset() {
    persister.removeFile()
    sessions = []
    activeSessionID = nil
  }
}
