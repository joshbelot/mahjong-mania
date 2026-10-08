import Foundation
import Testing

@testable import MahjongMania

private struct TestDoc: VersionedDocument, Equatable {
  static let currentVersion = 2
  var version = TestDoc.currentVersion
  var name = ""
  var when = Date(timeIntervalSince1970: 0)
  var items: [String: Int] = [:]

  private struct V1: Decodable {
    var title: String
  }

  static func migrate(from version: Int, data: Data, decoder: JSONDecoder) throws -> TestDoc {
    guard version == 1 else { throw JSONStoreError.unsupportedVersion(version) }
    let old = try decoder.decode(V1.self, from: data)
    return TestDoc(name: old.title)
  }
}

@MainActor
struct JSONFileStoreTests {
  private func store(_ directory: URL) -> JSONFileStore<TestDoc> {
    JSONFileStore<TestDoc>(directory: directory, name: "doc")
  }

  @Test func saveThenLoadRoundTrips() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    var doc = TestDoc(name: "Hello", when: Date(timeIntervalSince1970: 86_400), items: ["b": 2, "a": 1])
    doc.items["c"] = 3
    try file.save(doc)
    #expect(file.load() == doc)
    #expect(files(in: directory) == ["doc.json"])
  }

  @Test func filesUseSortedKeysAndIsoDates() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try file.save(TestDoc(name: "x", when: Date(timeIntervalSince1970: 0), items: ["z": 1, "a": 2]))
    let text = try String(contentsOf: file.url, encoding: .utf8)
    #expect(text.contains("1970-01-01T00:00:00Z"))
    #expect(text.contains("\"version\":2"))
    let a = try #require(text.range(of: "\"a\""))
    let z = try #require(text.range(of: "\"z\""))
    #expect(a.lowerBound < z.lowerBound)
  }

  @Test func missingFileLoadsNil() {
    #expect(store(makeTempDirectory()).load() == nil)
  }

  @Test func saveCreatesTheDirectory() throws {
    let directory = makeTempDirectory().appendingPathComponent("nested/deeper")
    try store(directory).save(TestDoc(name: "n"))
    #expect(store(directory).load()?.name == "n")
  }

  @Test func garbageIsQuarantinedNotDeleted() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try Data("this is not json".utf8).write(to: file.url)
    #expect(file.load() == nil)
    let names = files(in: directory)
    #expect(names.count == 1)
    #expect(names[0].hasPrefix("doc.corrupt-"))
    #expect(names[0].hasSuffix(".json"))
    let kept = try String(contentsOf: directory.appendingPathComponent(names[0]), encoding: .utf8)
    #expect(kept == "this is not json")
    // A fresh save works afterwards.
    try file.save(TestDoc(name: "fresh"))
    #expect(file.load()?.name == "fresh")
  }

  @Test func wrongShapeIsQuarantined() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try Data("{\"version\":2,\"name\":[1,2,3]}".utf8).write(to: file.url)
    #expect(file.load() == nil)
    #expect(files(in: directory).contains { $0.hasPrefix("doc.corrupt-") })
  }

  @Test func olderVersionsAreMigrated() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try Data("{\"version\":1,\"title\":\"Old name\"}".utf8).write(to: file.url)
    let loaded = try #require(file.load())
    #expect(loaded.name == "Old name")
    #expect(loaded.version == 2)
    #expect(files(in: directory) == ["doc.json"])
  }

  @Test func filesWithoutAVersionAreTreatedAsVersionOne() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try Data("{\"title\":\"Legacy\"}".utf8).write(to: file.url)
    #expect(file.load()?.name == "Legacy")
  }

  @Test func newerVersionsAreQuarantined() throws {
    let directory = makeTempDirectory()
    let file = store(directory)
    try Data("{\"version\":99,\"name\":\"future\"}".utf8).write(to: file.url)
    #expect(file.load() == nil)
    #expect(files(in: directory).contains { $0.hasPrefix("doc.corrupt-") })
  }

  @Test func unsupportedOldVersionIsQuarantined() throws {
    struct NoMigration: VersionedDocument {
      static let currentVersion = 3
      var version = 3
    }
    let directory = makeTempDirectory()
    let file = JSONFileStore<NoMigration>(directory: directory, name: "plain")
    try Data("{\"version\":2}".utf8).write(to: file.url)
    #expect(file.load() == nil)
    #expect(files(in: directory).contains { $0.hasPrefix("plain.corrupt-") })
  }
}

@MainActor
struct PersisterTests {
  @Test func rapidChangesCoalesceIntoOneWrite() async throws {
    let directory = makeTempDirectory()
    let file = JSONFileStore<TestDoc>(directory: directory, name: "doc")
    var current = TestDoc(name: "0")
    let persister = Persister(store: file, delay: .milliseconds(60))
    persister.snapshot = { current }
    for index in 1...10 {
      current.name = "\(index)"
      persister.changed()
    }
    #expect(persister.writeCount == 0)
    try await Task.sleep(for: .milliseconds(500))
    #expect(persister.writeCount == 1)
    #expect(file.load()?.name == "10")
  }

  @Test func flushWritesImmediatelyOnlyWhenPending() async throws {
    let directory = makeTempDirectory()
    let file = JSONFileStore<TestDoc>(directory: directory, name: "doc")
    let persister = Persister(store: file, delay: .milliseconds(60))
    persister.snapshot = { TestDoc(name: "now") }
    persister.flush()
    #expect(persister.writeCount == 0)
    persister.changed()
    persister.flush()
    #expect(persister.writeCount == 1)
    #expect(file.load()?.name == "now")
    try await Task.sleep(for: .milliseconds(300))
    #expect(persister.writeCount == 1)
  }

  @Test func removeFileCancelsPendingWork() async throws {
    let directory = makeTempDirectory()
    let file = JSONFileStore<TestDoc>(directory: directory, name: "doc")
    let persister = Persister(store: file, delay: .milliseconds(60))
    persister.snapshot = { TestDoc(name: "x") }
    persister.changed()
    persister.removeFile()
    try await Task.sleep(for: .milliseconds(300))
    #expect(persister.writeCount == 0)
    #expect(file.load() == nil)
  }
}
