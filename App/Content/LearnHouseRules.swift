import Foundation
import MahjongCore

/// "House rules explained": generated from the rule book, so it always matches what the app does
/// (SPEC §17.4). The user's own rules follow under "Our house rules".
enum LearnHouseRules {
  static let topicID = "houserules"

  static func topic(for rules: RuleSet) -> LearnTopic {
    var sections: [LearnSection] = []
    for category in RuleCategory.allCases {
      let definitions = RuleCatalog.builtIns.filter { $0.category == category }
      let items = definitions.compactMap { definition -> String? in
        guard let rule = rules.rule(definition.id) else { return nil }
        let text = RuleTexts.text(for: rule)
        let state = definition.locked ? "always on" : (rule.isEnabled ? "on" : "off")
        return "\(text.title) (\(state)). \(text.meaning)"
      }
      guard !items.isEmpty else { continue }
      var blocks: [LearnBlock] = [.bullets(items)]
      if category == .blanks {
        blocks.append(
          .paragraph(
            "A blank is a spare tile that never becomes part of a hand. With blanks on, the tile picker gets a Blank key, and the Helper never suggests passing or discarding one."
          ))
      }
      sections.append(LearnSection(id: "cat-\(category.rawValue)", heading: category.title, blocks: blocks))
    }
    let custom = rules.customRules
    let ours: [LearnBlock]
    if custom.isEmpty {
      ours = [
        .paragraph(
          "You haven't added any rules of your own yet. Add them in Settings, under House rules: a note for your table, or a scoring rule that changes what people pay."
        )
      ]
    } else {
      ours = [
        .bullets(
          custom.map { rule in
            let text = RuleTexts.text(for: rule)
            let state = rule.custom?.effect == nil ? "note" : (rule.isEnabled ? "on" : "off")
            return "\(text.title) (\(state)). \(text.meaning.replacingOccurrences(of: "\n\n", with: " "))"
          })
      ]
    }
    sections.append(LearnSection(id: "ours", heading: "Our house rules", blocks: ours))
    return LearnTopic(
      id: topicID, title: "House rules explained",
      summary: "Every rule in your rule book in plain words, and which ones are on.",
      symbol: "list.bullet.rectangle", sections: sections)
  }
}
