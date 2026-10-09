import SwiftUI

/// The glossary with a search field.
struct GlossaryView: View {
  @Environment(\.theme) private var theme
  @State private var query = ""

  private var entries: [GlossaryEntry] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return Glossary.entries }
    return Glossary.entries.filter {
      $0.term.localizedCaseInsensitiveContains(trimmed)
        || $0.definition.localizedCaseInsensitiveContains(trimmed)
    }
  }

  var body: some View {
    ScreenContainer {
      if entries.isEmpty {
        ContentUnavailableView.search(text: query)
          .frame(maxWidth: .infinity)
      } else {
        SectionCard {
          VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(entries) { entry in
              VStack(alignment: .leading, spacing: 2) {
                Text(entry.term)
                  .font(Typography.body.weight(.semibold))
                  .foregroundStyle(theme.text)
                  .accessibilityAddTraits(.isHeader)
                Text(entry.definition)
                  .font(Typography.small)
                  .foregroundStyle(theme.textMuted)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .accessibilityElement(children: .combine)
              if entry.id != entries.last?.id { Divider() }
            }
          }
        }
      }
    }
    .navigationTitle("Glossary")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $query, prompt: "Search terms")
  }
}

#Preview("Light") {
  NavigationStack { GlossaryView() }.preferredColorScheme(.light)
}

#Preview("Dark") {
  NavigationStack { GlossaryView() }.preferredColorScheme(.dark)
}
