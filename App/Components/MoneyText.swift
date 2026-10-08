import MahjongCore
import SwiftUI

/// Money from integer cents, formatted by `Scoring.formatMoney`; coloured by sign when `signed`.
struct MoneyText: View {
  @Environment(\.theme) private var theme
  let cents: Int
  var symbol = "$"
  var signed = true

  init(cents: Int, symbol: String = "$", signed: Bool = true) {
    self.cents = cents
    self.symbol = symbol
    self.signed = signed
  }

  var body: some View {
    Text(text)
      .font(Typography.body.weight(.semibold))
      .monospacedDigit()
      .foregroundStyle(color)
  }

  private var text: String {
    let base = Scoring.formatMoney(cents: cents, symbol: symbol)
    return signed && cents > 0 ? "+" + base : base
  }

  private var color: Color {
    guard signed else { return theme.text }
    if cents > 0 { return theme.success }
    if cents < 0 { return theme.danger }
    return theme.textMuted
  }
}

private struct MoneyPreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    HStack(spacing: Spacing.lg) {
      MoneyText(cents: 125)
      MoneyText(cents: -50)
      MoneyText(cents: 0)
      MoneyText(cents: 2500, signed: false)
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  MoneyPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  MoneyPreview().preferredColorScheme(.dark)
}
