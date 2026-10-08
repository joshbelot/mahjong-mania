import SwiftUI

/// A row with a title, optional subtitle and a trailing accessory.
struct ListRowView<Trailing: View>: View {
  @Environment(\.theme) private var theme
  private let title: String
  private let subtitle: String?
  private let trailing: Trailing

  init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: Spacing.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Typography.body)
          .foregroundStyle(theme.text)
        if let subtitle {
          Text(subtitle)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
      }
      Spacer(minLength: Spacing.sm)
      trailing
    }
    .frame(minHeight: 44)
    .contentShape(Rectangle())
  }
}

extension ListRowView where Trailing == EmptyView {
  init(_ title: String, subtitle: String? = nil) {
    self.init(title, subtitle: subtitle) { EmptyView() }
  }
}

#Preview("Light") {
  SectionCard {
    ListRowView("Bea", subtitle: "12 games") {
      Image(systemName: "chevron.right")
    }
    ListRowView("No subtitle")
  }
  .padding()
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  SectionCard {
    ListRowView("Bea", subtitle: "12 games") {
      Image(systemName: "chevron.right")
    }
    ListRowView("No subtitle")
  }
  .padding()
  .preferredColorScheme(.dark)
}
