import SwiftUI

/// A labelled value with − and + buttons and a configurable step.
struct StepperField: View {
  @Environment(\.theme) private var theme
  private let title: String
  private let value: Binding<Int>
  private let step: Int
  private let range: ClosedRange<Int>
  private let unit: String?

  init(
    _ title: String, value: Binding<Int>, step: Int = 1, range: ClosedRange<Int> = 0...9999,
    unit: String? = nil
  ) {
    self.title = title
    self.value = value
    self.step = step
    self.range = range
    self.unit = unit
  }

  var body: some View {
    HStack(spacing: Spacing.sm) {
      Text(title)
        .font(Typography.body)
        .foregroundStyle(theme.text)
      Spacer(minLength: Spacing.sm)
      stepButton(systemImage: "minus.circle.fill", delta: -step, label: "Decrease \(title)")
      Text(valueText)
        .font(Typography.body.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(theme.text)
        .frame(minWidth: 48)
        .contentTransition(.numericText())
      stepButton(systemImage: "plus.circle.fill", delta: step, label: "Increase \(title)")
    }
    .frame(minHeight: 44)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(valueText)
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: change(by: step)
      case .decrement: change(by: -step)
      @unknown default: break
      }
    }
  }

  private var valueText: String {
    if let unit { return "\(value.wrappedValue) \(unit)" }
    return "\(value.wrappedValue)"
  }

  private func change(by delta: Int) {
    let next = min(max(value.wrappedValue + delta, range.lowerBound), range.upperBound)
    withAnimation(.snappy(duration: 0.12)) { value.wrappedValue = next }
  }

  private func stepButton(systemImage: String, delta: Int, label: String) -> some View {
    let target = value.wrappedValue + delta
    let enabled = range.contains(target)
    return Button {
      change(by: delta)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 28))
        .foregroundStyle(enabled ? theme.primary : theme.textFaint)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityHidden(true)
  }
}

private struct StepperPreview: View {
  @Environment(\.theme) private var theme
  @State private var points = 25

  var body: some View {
    SectionCard {
      StepperField("Points", value: $points, step: 5, range: 0...500, unit: "pts")
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  StepperPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  StepperPreview().preferredColorScheme(.dark)
}
