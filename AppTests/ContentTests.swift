import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

struct ContentTests {
  private func strings(in block: LearnBlock) -> [String] {
    switch block {
    case .paragraph(let s), .note(let s): return [s]
    case .bullets(let items), .steps(let items): return items
    case .example(let notation, let caption): return [notation, caption]
    case .table(let header, let rows): return header + rows.flatMap { $0 }
    }
  }

  private var allTopicStrings: [String] {
    LearnContent.topics.flatMap { topic -> [String] in
      [topic.id, topic.title, topic.summary, topic.symbol]
        + topic.sections.flatMap { section -> [String] in
          [section.id, section.heading] + section.blocks.flatMap { strings(in: $0) }
        }
    }
  }

  private var allStrings: [String] {
    allTopicStrings
      + Glossary.entries.flatMap { [$0.term, $0.definition] }
      + Tips.all.flatMap { [$0.id, $0.text] }
  }

  @Test func topicsAreInOrderAndFindable() {
    #expect(LearnContent.topics.map(\.id) == ["rules", "tiles", "reading", "notation"])
    for topic in LearnContent.topics {
      #expect(LearnContent.topic(id: topic.id) == topic)
    }
    #expect(LearnContent.topic(id: "nope") == nil)
  }

  @Test func idsAreUnique() {
    let topicIDs = LearnContent.topics.map(\.id)
    #expect(Set(topicIDs).count == topicIDs.count)
    for topic in LearnContent.topics {
      let ids = topic.sections.map(\.id)
      #expect(Set(ids).count == ids.count)
    }
  }

  @Test func rulesHasElevenSections() {
    #expect(LearnContent.topic(id: "rules")?.sections.count == 11)
  }

  @Test func everyExampleParses() {
    var count = 0
    for topic in LearnContent.topics {
      for section in topic.sections {
        for block in section.blocks {
          if case .example(let notation, _) = block {
            count += 1
            if case .failure(let list) = Notation.parseLine(notation) {
              Issue.record("Example failed: \(notation) \(list.errors.map(\.message))")
            }
          }
        }
      }
    }
    #expect(count >= 8)
    let guideCount =
      LearnNotation.topic.sections.flatMap(\.blocks).filter {
        if case .example = $0 { return true } else { return false }
      }.count
    #expect(guideCount >= 8)
  }

  @Test func glossaryCoversRequiredTerms() {
    let required = [
      "Bam", "Crak", "Dot", "Soap", "Flower", "Joker", "Wind", "Dragon", "Matching dragon",
      "Single", "Pair", "Pung", "Kong", "Quint", "Sextet", "Exposure", "Concealed (C)",
      "Exposed (X)", "Charleston", "Blind pass", "Courtesy pass", "Rack", "Wall",
      "East (Dealer)", "Self-pick", "Jokerless", "Dead hand", "Wall game", "Joker exchange",
      "Calling", "Mahjong", "Family (Section)", "Like numbers", "Consecutive run",
      "Singles & Pairs", "Hot tile",
    ]
    let terms = Set(Glossary.entries.map(\.term))
    for term in required { #expect(terms.contains(term), "Missing \(term)") }
  }

  @Test func glossaryIsSortedAndUnique() {
    let terms = Glossary.entries.map { $0.term.lowercased() }
    #expect(terms == terms.sorted())
    #expect(Set(terms).count == terms.count)
  }

  @Test func tipsAreSufficientAndUnique() {
    #expect(Tips.all.count >= 15)
    #expect(Set(Tips.all.map(\.id)).count == Tips.all.count)
  }

  @Test func nextTipNeverRepeatsAndIsDeterministic() {
    var shown = Set<String>()
    var seed: UInt64 = 7
    while let tip = Tips.next(after: shown, seed: seed) {
      #expect(!shown.contains(tip.id))
      #expect(Tips.next(after: shown, seed: seed) == tip)
      shown.insert(tip.id)
      seed &+= 1
    }
    #expect(shown.count == Tips.all.count)
    #expect(Tips.next(after: shown, seed: 1) == nil)
  }

  @Test func contentIsCleanAndNonEmpty() {
    for s in allStrings {
      #expect(!s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      #expect(!s.contains("NMJL"))
      #expect(!s.contains("National Mah Jongg"))
    }
    for topic in LearnContent.topics {
      #expect(!topic.sections.isEmpty)
      for section in topic.sections { #expect(!section.blocks.isEmpty) }
    }
    for entry in Glossary.entries { #expect(!entry.definition.isEmpty) }
  }
}
