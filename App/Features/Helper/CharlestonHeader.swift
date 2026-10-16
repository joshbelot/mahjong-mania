import SwiftUI

/// The Charleston's seat switch and pass tracker (SPEC §17.3): "I'm East (dealer) · 14 tiles",
/// "Pass 1 of 7 · Right", "Stop after this Charleston" and "Start over".
struct CharlestonHeader: View {
  @Environment(\.theme) private var theme
  @Environment(HelperStore.self) private var helper

  let onSwitchToPlaying: () -> Void

  private var eastBinding: Binding<Bool> {
    let helper = helper
    return Binding(
      get: { MainActor.assumeIsolated { helper.isEast } },
      set: { newValue in MainActor.assumeIsolated { helper.setEast(newValue) } })
  }

  var body: some View {
    SectionCard {
      Toggle(isOn: eastBinding) {
        Text("I'm East (dealer) \u{00B7} 14 tiles")
          .font(Typography.body)
          .foregroundStyle(theme.text)
      }
      .tint(theme.primary)
      .accessibilityHint("The dealer starts with 14 tiles, everyone else with 13")
      .accessibilityIdentifier("charleston.east")

      Text(helper.trackerText)
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("charleston.tracker")

      if helper.isCharlestonDone {
        Text("Everyone has passed. Time to play.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        Button("Switch to Playing", action: onSwitchToPlaying)
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("charleston.toPlaying")
      }
      AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.sm) {
        if helper.canStopAfterFirst {
          Button("Stop after this Charleston") {
            withAnimation(.smooth(duration: 0.2)) { helper.stopAfterFirstCharleston() }
          }
          .buttonStyle(PrimaryButton(.secondary))
          .accessibilityHint("Skips the second Charleston")
          .accessibilityIdentifier("charleston.stop")
        }
        Button("Start over") {
          withAnimation(.smooth(duration: 0.2)) { helper.restartCharleston() }
        }
        .buttonStyle(PrimaryButton(.ghost))
        .accessibilityHint("Goes back to pass 1 and keeps your tiles")
        .accessibilityIdentifier("charleston.restart")
      }
    }
  }
}
