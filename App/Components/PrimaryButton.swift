import SwiftUI

/// Button style with four looks and two sizes. `.large` is 56 pt tall for use at the table.
struct PrimaryButton: ButtonStyle {
  enum Kind: Sendable { case primary, secondary, ghost, destructive }
  enum Size: Sendable { case regular, large }

  let kind: Kind
  let size: Size
  let fullWidth: Bool

  init(_ kind: Kind = .primary, size: Size = .regular, fullWidth: Bool? = nil) {
    self.kind = kind
    self.size = size
    self.fullWidth = fullWidth ?? (size == .large)
  }

  func makeBody(configuration: Configuration) -> some View {
    PrimaryButtonBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
  }
}

private struct PrimaryButtonBody: View {
  @Environment(\.theme) private var theme
  @Environment(\.isEnabled) private var isEnabled
  let configuration: ButtonStyleConfiguration
  let kind: PrimaryButton.Kind
  let size: PrimaryButton.Size
  let fullWidth: Bool

  var body: some View {
    configuration.label
      .font(Typography.body.weight(.semibold))
      .multilineTextAlignment(.center)
      .foregroundStyle(foreground)
      .padding(.horizontal, Spacing.lg)
      .frame(maxWidth: maxWidth, minHeight: size == .large ? 56 : 44)
      .background(background, in: RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(RoundedRectangle(cornerRadius: Radius.md))
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.snappy(duration: 0.12), value: configuration.isPressed)
  }

  private var maxWidth: CGFloat? { fullWidth ? CGFloat.infinity : nil }

  private var foreground: Color {
    switch kind {
    case .primary, .destructive: return theme.onPrimary
    case .secondary, .ghost: return theme.primary
    }
  }

  private var background: Color {
    switch kind {
    case .primary: return theme.primary
    case .secondary: return theme.primarySoft
    case .ghost: return .clear
    case .destructive: return theme.danger
    }
  }
}

private struct PrimaryButtonPreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    VStack(spacing: Spacing.md) {
      Button("Primary") {}.buttonStyle(PrimaryButton(.primary))
      Button("Secondary") {}.buttonStyle(PrimaryButton(.secondary))
      Button("Ghost") {}.buttonStyle(PrimaryButton(.ghost))
      Button("Destructive") {}.buttonStyle(PrimaryButton(.destructive))
      Button("Large primary") {}.buttonStyle(PrimaryButton(.primary, size: .large))
      Button("Disabled") {}.buttonStyle(PrimaryButton(.primary)).disabled(true)
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  PrimaryButtonPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  PrimaryButtonPreview().preferredColorScheme(.dark)
}
