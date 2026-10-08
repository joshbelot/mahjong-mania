import SwiftUI

/// Wraps `ContentUnavailableView` with an optional action button.
struct EmptyStateView: View {
  @Environment(\.theme) private var theme
  private let title: String
  private let systemImage: String
  private let message: String?
  private let actionTitle: String?
  private let action: (() -> Void)?

  init(
    _ title: String, systemImage: String, message: String? = nil, actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.title = title
    self.systemImage = systemImage
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
        .foregroundStyle(theme.text)
    } description: {
      if let message {
        Text(message).foregroundStyle(theme.textMuted)
      }
    } actions: {
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .buttonStyle(PrimaryButton(.primary))
      }
    }
  }
}

#Preview("Light") {
  EmptyStateView(
    "No players yet", systemImage: "person.2", message: "Add the people you play with.",
    actionTitle: "Add player"
  ) {}
  .preferredColorScheme(.light)
}

#Preview("Dark") {
  EmptyStateView(
    "No players yet", systemImage: "person.2", message: "Add the people you play with.",
    actionTitle: "Add player"
  ) {}
  .preferredColorScheme(.dark)
}
