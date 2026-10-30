import SwiftUI
import Testing
import UIKit

@testable import MahjongMania

/// SPEC §19.4 step 6. Text the app puts on its backgrounds must reach WCAG AA (4.5:1). The accessibility
/// audit found the locked path titles in `textFaint` (about 2.5:1); they now use `textMuted`.
@MainActor
struct ContrastTests {
  private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
    let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
    func lin(_ c: CGFloat) -> Double { c <= 0.03928 ? Double(c) / 12.92 : pow((Double(c) + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
  }

  private func ratio(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
    let (x, y) = (luminance(a, style), luminance(b, style))
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)
  }

  @Test func mutedTextReadsOnEveryBackground() {
    let theme = Theme.standard
    for style in [UIUserInterfaceStyle.light, .dark] {
      for background in [theme.bg, theme.surface, theme.surfaceAlt] {
        #expect(ratio(theme.textMuted, background, style) >= 4.5, "textMuted on a background in \(style.rawValue)")
        #expect(ratio(theme.text, background, style) >= 7)
      }
    }
  }
}
