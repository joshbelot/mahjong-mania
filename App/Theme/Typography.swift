import SwiftUI

/// Text styles from SPEC §11.2. System text styles keep Dynamic Type working.
enum Typography {
  static let title = Font.largeTitle.weight(.semibold)
  static let h2 = Font.title3.weight(.semibold)
  static let body = Font.body
  static let small = Font.footnote
  static let tiny = Font.caption2.weight(.semibold)
}

extension View {
  func titleStyle() -> some View {
    font(Typography.title).fontDesign(.serif)
  }

  func h2Style() -> some View {
    font(Typography.h2)
  }

  func tinyStyle() -> some View {
    font(Typography.tiny).textCase(.uppercase).tracking(0.6)
  }
}
