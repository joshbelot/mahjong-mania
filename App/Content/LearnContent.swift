import Foundation

/// One piece of a Learn section. Plain data so views can render it however they like.
enum LearnBlock: Sendable, Hashable {
  case paragraph(String)
  case bullets([String])
  case steps([String])
  /// `notation` is a full card-file line (e.g. `FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs`).
  case example(notation: String, caption: String)
  case table(header: [String], rows: [[String]])
  case note(String)
}

struct LearnSection: Sendable, Hashable, Identifiable {
  let id: String
  let heading: String
  let blocks: [LearnBlock]

  init(id: String, heading: String, blocks: [LearnBlock]) {
    self.id = id
    self.heading = heading
    self.blocks = blocks
  }
}

struct LearnTopic: Sendable, Hashable, Identifiable {
  let id: String
  let title: String
  let summary: String
  /// SF Symbol name.
  let symbol: String
  let sections: [LearnSection]

  init(id: String, title: String, summary: String, symbol: String, sections: [LearnSection]) {
    self.id = id
    self.title = title
    self.summary = summary
    self.symbol = symbol
    self.sections = sections
  }
}

enum LearnContent {
  /// The prose topics, in display order. The glossary lives in `Glossary`.
  static let topics: [LearnTopic] = [
    LearnRules.topic,
    LearnTiles.topic,
    LearnReading.topic,
    LearnNotation.topic,
  ]

  static func topic(id: String) -> LearnTopic? {
    topics.first { $0.id == id }
  }
}
