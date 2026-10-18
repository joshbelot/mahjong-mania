import MahjongCore
import SwiftUI

/// What happened to the streak while the app was away: a freeze that saved it, or a gentle restart.
/// Dismissible and never shaming (SPEC §18.6).
struct StreakBanners: View {
  @Environment(\.theme) private var theme
  @Environment(PracticeStore.self) private var practice

  var body: some View {
    ForEach(Array(practice.pendingStreakEvents.enumerated()), id: \.offset) { entry in
      switch entry.element {
      case .freezeUsed(_, let streak):
        banner(
          "snowflake", theme.primary, StreakLogic.freezeMessage(streak: streak), id: "banner.freeze")
      case .streakLost(_, let played):
        banner("sun.max.fill", theme.gold, StreakLogic.brokenMessage(daysPlayed: played), id: "banner.broken")
      default:
        EmptyView()
      }
    }
  }

  private func banner(_ symbol: String, _ tint: Color, _ text: String, id: String) -> some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(tint)
        .accessibilityHidden(true)
      Text(text)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        practice.clearPendingStreakEvents()
      } label: {
        Image(systemName: "xmark")
          .font(.footnote.weight(.bold))
          .foregroundStyle(theme.textMuted)
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel("Dismiss")
      .accessibilityIdentifier("\(id).dismiss")
    }
    .padding(.leading, Spacing.lg)
    .padding(.vertical, Spacing.xs)
    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(tint.opacity(0.5), lineWidth: 1))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(id)
  }
}
