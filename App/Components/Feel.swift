import SwiftUI

/// A horizontal wobble that returns to rest when `shakes` is a whole number: three cycles per unit.
struct ShakeEffect: GeometryEffect {
  var shakes: CGFloat
  var distance: CGFloat = 8

  var animatableData: CGFloat {
    get { shakes }
    set { shakes = newValue }
  }

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: distance * sin(shakes * .pi * 6), y: 0))
  }
}

extension View {
  /// Shakes (0.3 s) each time `count` goes up, unless Reduce Motion is on.
  func shake(_ count: Int) -> some View {
    modifier(ShakeModifier(count: count))
  }

  /// A quick pop (1 → 1.08 → 1, 0.25 s) each time `trigger` changes; nothing when `enabled` is false.
  func pop(trigger: Int, enabled: Bool = true) -> some View {
    modifier(PopModifier(trigger: trigger, enabled: enabled))
  }

  /// `.sensoryFeedback` that picks the feedback from the new value and respects the Haptics setting.
  func hapticOnChange<Trigger: Equatable>(
    trigger: Trigger, _ feedback: @escaping (Trigger) -> SensoryFeedback?
  ) -> some View {
    modifier(HapticOnChange(trigger: trigger, feedback: feedback))
  }
}

private struct ShakeModifier: ViewModifier {
  @Environment(\.reduceMotion) private var reduceMotion
  let count: Int

  func body(content: Content) -> some View {
    content
      .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(count)))
      .animation(reduceMotion ? nil : .linear(duration: 0.3), value: count)
  }
}

private struct PopModifier: ViewModifier {
  @Environment(\.reduceMotion) private var reduceMotion
  let trigger: Int
  let enabled: Bool

  func body(content: Content) -> some View {
    if reduceMotion || !enabled {
      content
    } else {
      content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
        view.scaleEffect(scale)
      } keyframes: { _ in
        SpringKeyframe(1.08, duration: 0.1, spring: .snappy)
        SpringKeyframe(1.0, duration: 0.15, spring: .bouncy)
      }
    }
  }
}

private struct HapticOnChange<Trigger: Equatable>: ViewModifier {
  @Environment(\.hapticsEnabled) private var enabled
  let trigger: Trigger
  let feedback: (Trigger) -> SensoryFeedback?

  func body(content: Content) -> some View {
    content.sensoryFeedback(trigger: trigger) { _, new in enabled ? feedback(new) : nil }
  }
}

/// A check mark that draws itself in 0.25 s (instantly with Reduce Motion).
struct DrawnCheckmark: View {
  @Environment(\.reduceMotion) private var reduceMotion
  let color: Color
  @State private var progress: CGFloat = 0

  var body: some View {
    ZStack {
      Circle().fill(color)
      CheckShape()
        .trim(from: 0, to: reduceMotion ? 1 : progress)
        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .padding(8)
    }
    .frame(width: 30, height: 30)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeOut(duration: 0.25).delay(0.05)) { progress = 1 }
    }
    .accessibilityHidden(true)
  }
}

struct CheckShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY + rect.height * 0.05))
    path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.12))
    path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.minY + rect.height * 0.12))
    return path
  }
}

/// "+10" that floats up from where it appears and fades out (nothing with Reduce Motion).
struct FloatingXP: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let amount: Int
  @State private var risen = false

  var body: some View {
    if amount > 0 && !reduceMotion {
      Text("+\(amount)")
        .font(.title.weight(.heavy).monospacedDigit())
        .foregroundStyle(theme.success)
        .shadow(color: theme.bg, radius: 2)
        .offset(y: risen ? -64 : -8)
        .opacity(risen ? 0 : 1)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { risen = true } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }
}

private struct ReduceMotionKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Reduce Motion: the system setting, or `-UITestReduceMotion` so UI tests can look at both versions.
  var reduceMotion: Bool {
    get { self[ReduceMotionKey.self] }
    set { self[ReduceMotionKey.self] = newValue }
  }
}

/// Sets `reduceMotion` once at the app root.
struct MotionSettings: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var system

  func body(content: Content) -> some View {
    content.environment(\.reduceMotion, system || ProcessInfo.processInfo.arguments.contains("-UITestReduceMotion"))
  }
}
