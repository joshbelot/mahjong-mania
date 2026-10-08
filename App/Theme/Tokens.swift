import SwiftUI
import UIKit

/// Design tokens from SPEC §11.2. This is the only file allowed to contain literal colour values.
extension UIColor {
  convenience init(hex: UInt32, alpha: CGFloat = 1) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: alpha)
  }
}

extension Color {
  /// A colour that resolves to `light` or `dark` depending on the current interface style.
  static func dynamic(
    light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
  ) -> Color {
    Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(hex: dark, alpha: darkAlpha)
          : UIColor(hex: light, alpha: lightAlpha)
      })
  }

  /// A fixed (non-adaptive) colour.
  static func fixed(_ hex: UInt32, alpha: CGFloat = 1) -> Color {
    Color(UIColor(hex: hex, alpha: alpha))
  }
}

enum Spacing {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
}

enum Radius {
  static let sm: CGFloat = 6
  static let md: CGFloat = 10
  static let lg: CGFloat = 16
  static let pill: CGFloat = 999
}

/// The 8-colour player palette (SPEC §11.4), indexed by `Player.colorIndex`.
enum PlayerPalette {
  static let hexes: [UInt32] = [
    0x1F6B52, 0xC8423B, 0x2F5D9E, 0xB8862A, 0x8A4FA3, 0x2E8A8A, 0xD9673A, 0x5E665F,
  ]

  static func color(at index: Int) -> Color {
    let count = hexes.count
    let safe = ((index % count) + count) % count
    return Color.fixed(hexes[safe])
  }
}

struct Theme: Sendable {
  let bg = Color.dynamic(light: 0xF7F3EA, dark: 0x121614)
  let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1B201D)
  let surfaceAlt = Color.dynamic(light: 0xEFE8D8, dark: 0x242A26)
  let border = Color.dynamic(light: 0xE1D8C4, dark: 0x2F3631)
  let text = Color.dynamic(light: 0x1E2420, dark: 0xECE7DC)
  let textMuted = Color.dynamic(light: 0x5E665F, dark: 0xA3A99F)
  let textFaint = Color.dynamic(light: 0x8C928A, dark: 0x737A72)
  let primary = Color.dynamic(light: 0x1F6B52, dark: 0x4FB38C)
  let onPrimary = Color.dynamic(light: 0xFFFFFF, dark: 0x0E1411)
  let primarySoft = Color.dynamic(light: 0xDCEBE4, dark: 0x1F3A2F)
  let accent = Color.dynamic(light: 0xC8423B, dark: 0xE2675F)
  let gold = Color.dynamic(light: 0xB8862A, dark: 0xE0B451)
  let success = Color.dynamic(light: 0x2E7D4F, dark: 0x5BBF86)
  let warning = Color.dynamic(light: 0xB7791F, dark: 0xE0A84F)
  let danger = Color.dynamic(light: 0xB3261E, dark: 0xF2766D)
  let tileFace = Color.dynamic(light: 0xFFFDF7, dark: 0xF4EFE3)
  let tileEdge = Color.dynamic(light: 0x1F6B52, dark: 0x2E8A69)
  let tileShadow = Color.dynamic(
    light: 0x1E2420, dark: 0x000000, lightAlpha: 0.18, darkAlpha: 0.5)
  // Tile faces stay ivory in dark mode, so suit inks do not adapt.
  let suitC = Color.fixed(0xC8423B)
  let suitB = Color.fixed(0x2E7D4F)
  let suitD = Color.fixed(0x2F5D9E)
  // Card-style colours for suit variables x / y / z (shown to users as A / B / C).
  let varA = Color.dynamic(light: 0x2F5D9E, dark: 0x7FA6E0)
  let varB = Color.dynamic(light: 0xC8423B, dark: 0xE2675F)
  let varC = Color.dynamic(light: 0x2E7D4F, dark: 0x5BBF86)
  // Ink for winds and other dark glyphs on the ivory tile face (does not adapt, like the face itself).
  let tileInk = Color.fixed(0x1E2420)
  let flower = Color.fixed(0x8A4FA3)
  let joker = Color.fixed(0xB8862A)

  static let standard = Theme()
}
