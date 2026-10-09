import SwiftUI

private struct HapticsEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  /// Mirrors `settings.haptics`; set once at the app root.
  var hapticsEnabled: Bool {
    get { self[HapticsEnabledKey.self] }
    set { self[HapticsEnabledKey.self] = newValue }
  }
}

private struct GatedHaptic<Trigger: Equatable>: ViewModifier {
  @Environment(\.hapticsEnabled) private var enabled
  let feedback: SensoryFeedback
  let trigger: Trigger

  func body(content: Content) -> some View {
    content.sensoryFeedback(trigger: trigger) { _, _ in enabled ? feedback : nil }
  }
}

extension View {
  /// `.sensoryFeedback` that respects the Haptics setting.
  func haptic<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
    modifier(GatedHaptic(feedback: feedback, trigger: trigger))
  }
}
