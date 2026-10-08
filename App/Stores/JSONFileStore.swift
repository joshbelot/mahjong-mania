import Foundation
import os

/// A document stored as one JSON file with a top-level `version` field (SPEC §7.5).
protocol VersionedDocument: Codable, Sendable {
  static var currentVersion: Int { get }
  var version: Int { get }
  /// Upgrades `data` written by an older app version. The default implementation rejects every old version,
  /// which makes the file get quarantined; override it when version 2 of a document is introduced.
  static func migrate(from version: Int, data: Data, decoder: JSONDecoder) throws -> Self
}

enum JSONStoreError: Error, Equatable {
  case unsupportedVersion(Int)
}

extension VersionedDocument {
  static func migrate(from version: Int, data: Data, decoder: JSONDecoder) throws -> Self {
    throw JSONStoreError.unsupportedVersion(version)
  }
}

private struct VersionProbe: Decodable {
  var version: Int?
}

/// Reads and writes one JSON file. Writes are atomic; a file that cannot be decoded is moved aside to
/// `<name>.corrupt-<timestamp>.json` so the app starts fresh without destroying the data.
struct JSONFileStore<Value: VersionedDocument>: Sendable {
  let url: URL

  init(directory: URL, name: String) {
    url = directory.appendingPathComponent(name).appendingPathExtension("json")
  }

  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  /// nil when the file is missing or unusable (in which case an unusable file is quarantined).
  func load() -> Value? {
    let manager = FileManager.default
    guard manager.fileExists(atPath: url.path) else { return nil }
    do {
      let data = try Data(contentsOf: url)
      let decoder = Self.makeDecoder()
      let version = try decoder.decode(VersionProbe.self, from: data).version ?? 1
      if version == Value.currentVersion {
        return try decoder.decode(Value.self, from: data)
      }
      if version < Value.currentVersion {
        return try Value.migrate(from: version, data: data, decoder: decoder)
      }
      throw JSONStoreError.unsupportedVersion(version)
    } catch {
      Log.storage.error("Quarantining \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
      quarantine()
      return nil
    }
  }

  func save(_ value: Value) throws {
    let manager = FileManager.default
    try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try Self.makeEncoder().encode(value)
    try data.write(to: url, options: .atomic)
  }

  func remove() {
    try? FileManager.default.removeItem(at: url)
  }

  private func quarantine() {
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    let name = url.deletingPathExtension().lastPathComponent
    let target = url.deletingLastPathComponent().appendingPathComponent("\(name).corrupt-\(stamp).json")
    do {
      try FileManager.default.moveItem(at: url, to: target)
    } catch {
      try? FileManager.default.removeItem(at: url)
    }
  }
}

enum Log {
  static let storage = Logger(subsystem: "com.joshbelot.mahjongmania", category: "storage")
}

/// Debounced writer: `changed()` schedules a save 0.3 s later and coalesces bursts into one write.
@MainActor
final class Persister<Value: VersionedDocument> {
  private let store: JSONFileStore<Value>
  private let delay: Duration
  private var task: Task<Void, Never>?
  /// Number of writes performed (used by tests).
  private(set) var writeCount = 0
  /// Produces the document to write; set by the owning store once it is fully initialised.
  var snapshot: (@MainActor () -> Value?)?

  init(store: JSONFileStore<Value>, delay: Duration = .milliseconds(300)) {
    self.store = store
    self.delay = delay
  }

  func changed() {
    task?.cancel()
    task = Task { [delay] in
      _ = try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      self.writeNow()
    }
  }

  /// Writes immediately if a save is pending (called when the app goes to the background).
  func flush() {
    guard task != nil else { return }
    task?.cancel()
    writeNow()
  }

  /// Drops any pending save and deletes the file.
  func removeFile() {
    task?.cancel()
    task = nil
    store.remove()
  }

  private func writeNow() {
    task = nil
    guard let value = snapshot?() else { return }
    writeCount += 1
    do {
      try store.save(value)
    } catch {
      Log.storage.error("Save failed: \(String(describing: error), privacy: .public)")
    }
  }
}
