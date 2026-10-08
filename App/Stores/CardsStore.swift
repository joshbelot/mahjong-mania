import MahjongCore
import Observation
import SwiftUI

/// A user-entered card, persisted as card-file text (SPEC §9.5) and parsed on load.
struct UserCardRecord: Codable, Hashable, Sendable, Identifiable {
  var id: String
  var name: String
  var year: Int?
  var text: String
  var createdAt: Date
  var updatedAt: Date
}

struct CardsDocument: VersionedDocument, Equatable {
  static let currentVersion = 1
  var version = CardsDocument.currentVersion
  var userCards: [UserCardRecord] = []
}

@MainActor
@Observable
final class CardsStore {
  private(set) var records: [UserCardRecord]
  @ObservationIgnored private let persister: Persister<CardsDocument>
  @ObservationIgnored private var parsed: [String: (updatedAt: Date, card: Card)] = [:]
  @ObservationIgnored private var analyzers: [String: (updatedAt: Date, analyzer: Analyzer)] = [:]
  /// How many times card text has been parsed (used by tests to prove the cache works).
  @ObservationIgnored private(set) var parseCount = 0

  init(directory: URL, persistDelay: Duration = .milliseconds(300)) {
    let file = JSONFileStore<CardsDocument>(directory: directory, name: "cards")
    records = file.load()?.userCards ?? []
    persister = Persister(store: file, delay: persistDelay)
    persister.snapshot = { [weak self] in self.map { CardsDocument(userCards: $0.records) } }
  }

  /// The Practice Card followed by the user's cards.
  var cards: [Card] { [PracticeCard.card] + records.map { card(for: $0) } }

  func card(id: String) -> Card? {
    if id == PracticeCard.card.id { return PracticeCard.card }
    return records.first { $0.id == id }.map { card(for: $0) }
  }

  func record(id: String) -> UserCardRecord? { records.first { $0.id == id } }

  /// Parsed card for a record; re-parsed only when `updatedAt` changes.
  func card(for record: UserCardRecord) -> Card {
    if let cached = parsed[record.id], cached.updatedAt == record.updatedAt { return cached.card }
    parseCount += 1
    let result = Notation.parseCardFile(record.text)
    let card = Card(
      id: record.id, name: record.name, year: record.year ?? result.year, builtIn: false,
      lines: result.lines, createdAt: record.createdAt, updatedAt: record.updatedAt)
    parsed[record.id] = (record.updatedAt, card)
    return card
  }

  /// One `Analyzer` per card version; the analyzer is rebuilt when the card's `updatedAt` changes.
  func analyzer(for cardID: String) -> Analyzer? {
    guard let card = card(id: cardID) else { return nil }
    if let cached = analyzers[cardID], cached.updatedAt == card.updatedAt { return cached.analyzer }
    let analyzer = Analyzer(card: card)
    analyzers[cardID] = (card.updatedAt, analyzer)
    return analyzer
  }

  /// Parse problems in a user card's text (for the import/editor screens).
  func problems(in cardID: String) -> [CardFileError] {
    guard let record = record(id: cardID) else { return [] }
    return Notation.parseCardFile(record.text).errors
  }

  @discardableResult
  func createCard(
    name: String, year: Int? = nil, text: String? = nil, id: String = UUID().uuidString, at date: Date = Date()
  ) -> UserCardRecord {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let body = text ?? "! \(trimmed)\n" + (year.map { "!year \($0)\n" } ?? "")
    let record = UserCardRecord(id: id, name: trimmed, year: year, text: body, createdAt: date, updatedAt: date)
    records.append(record)
    persister.changed()
    return record
  }

  func updateText(id: String, text: String, at date: Date = Date()) {
    mutate(id, at: date) { $0.text = text }
  }

  /// Renames the card and rewrites the `!` header line so the text and the record agree.
  func rename(id: String, to name: String, at date: Date = Date()) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    mutate(id, at: date) { record in
      record.name = trimmed
      record.text = Self.replacingHeaderName(in: record.text, with: trimmed)
    }
  }

  /// Replaces the card-file name line (`! Name`), or adds one at the top. Other lines are left alone, so
  /// lines that currently have errors are not lost.
  static func replacingHeaderName(in text: String, with name: String) -> String {
    var lines = text.components(separatedBy: "\n")
    let header = "! \(name)"
    if let index = lines.firstIndex(where: {
      let trimmed = $0.trimmingCharacters(in: .whitespaces)
      return trimmed.hasPrefix("!") && !(trimmed == "!year" || trimmed.hasPrefix("!year "))
    }) {
      lines[index] = header
    } else {
      lines.insert(header, at: 0)
    }
    return lines.joined(separator: "\n")
  }

  func setYear(id: String, year: Int?, at date: Date = Date()) {
    mutate(id, at: date) { $0.year = year }
  }

  /// Copies any card (including the built-in one) into a new editable card.
  @discardableResult
  func duplicate(
    cardID: String, name: String? = nil, id: String = UUID().uuidString, at date: Date = Date()
  ) -> UserCardRecord? {
    guard let source = card(id: cardID) else { return nil }
    let copyName = name ?? "\(source.name) copy"
    var copy = source
    copy.name = copyName
    return createCard(name: copyName, year: source.year, text: Notation.serialize(copy), id: id, at: date)
  }

  /// Appends valid lines (card-file text) to an existing card under their own `#` sections.
  func append(text: String, to id: String, at date: Date = Date()) {
    mutate(id, at: date) { record in
      var existing = record.text
      if !existing.hasSuffix("\n") { existing += "\n" }
      record.text = existing + text + (text.hasSuffix("\n") ? "" : "\n")
    }
  }

  func delete(id: String) {
    records.removeAll { $0.id == id }
    parsed[id] = nil
    analyzers[id] = nil
    persister.changed()
  }

  private func mutate(_ id: String, at date: Date, _ change: (inout UserCardRecord) -> Void) {
    guard let index = records.firstIndex(where: { $0.id == id }) else { return }
    change(&records[index])
    records[index].updatedAt = date
    persister.changed()
  }

  func flush() { persister.flush() }

  func reset() {
    persister.removeFile()
    records = []
    parsed = [:]
    analyzers = [:]
  }
}
