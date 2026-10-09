import SwiftUI

/// Renders a `LearnTopic`: a summary, then each section with its blocks.
struct LearnTopicView: View {
  @Environment(\.theme) private var theme
  let topic: LearnTopic

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.xl) {
        Text(topic.summary)
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
        ForEach(topic.sections) { section in
          VStack(alignment: .leading, spacing: Spacing.md) {
            Text(section.heading)
              .h2Style()
              .foregroundStyle(theme.text)
              .accessibilityAddTraits(.isHeader)
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { entry in
              LearnBlockView(block: entry.element, showSource: topic.id == "notation")
            }
          }
        }
        Text(
          "Table procedures here describe the standard way. Your card's printed rules and your group's house rules come first."
        )
        .font(Typography.small)
        .foregroundStyle(theme.textFaint)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .navigationTitle(topic.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview("Light") {
  NavigationStack {
    if let topic = LearnContent.topic(id: "notation") { LearnTopicView(topic: topic) }
  }
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack {
    if let topic = LearnContent.topic(id: "notation") { LearnTopicView(topic: topic) }
  }
  .preferredColorScheme(.dark)
}
