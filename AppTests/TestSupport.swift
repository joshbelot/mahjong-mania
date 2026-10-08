import Foundation

/// A fresh, empty temporary directory for one test.
func makeTempDirectory() -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("MahjongManiaTests-\(UUID().uuidString)", isDirectory: true)
  try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

func files(in directory: URL) -> [String] {
  ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
}
