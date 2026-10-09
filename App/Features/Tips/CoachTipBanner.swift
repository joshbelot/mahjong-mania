import SwiftUI

/// A dismissible coach tip. Shows nothing unless the assist level is Coach. Drop it at the top of a
/// screen with a unique `screen` key: `CoachTipBanner(screen: "learn.home")`.
struct CoachTipBanner: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(TipCenter.self) private var tips
  @State private var hidden = false

  let screen: String

  var body: some View {
    if settings.settings.assistLevel == .coach, !hidden, let tip = tips.tip(for: screen) {
      HStack(alignment: .top, spacing: Spacing.md) {
        Image(systemName: "lightbulb.fill")
          .foregroundStyle(theme.gold)
          .padding(.top, Spacing.sm)
          .accessibilityHidden(true)
        Text(tip.text)
          .font(Typography.small)
          .foregroundStyle(theme.text)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, Spacing.sm)
          .accessibilityIdentifier("coach.tip")
        Button {
          withAnimation(.smooth(duration: 0.2)) {
            tips.dismiss(screen: screen)
            hidden = true
          }
        } label: {
          Image(systemName: "xmark")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.textMuted)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss tip")
        .accessibilityIdentifier("coach.tip.dismiss")
      }
      .padding(.leading, Spacing.md)
      .background(theme.primarySoft, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
      .accessibilityElement(children: .contain)
    }
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  stores.settings.update { $0.assistLevel = .coach }
  return CoachTipBanner(screen: "preview")
    .padding()
    .environment(stores.settings)
    .environment(TipCenter(seed: 1))
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  stores.settings.update { $0.assistLevel = .coach }
  return CoachTipBanner(screen: "preview")
    .padding()
    .environment(stores.settings)
    .environment(TipCenter(seed: 1))
    .preferredColorScheme(.dark)
}
