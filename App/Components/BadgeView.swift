import SwiftUI

/// Small status pill: X / C hand type, Dead, East dealer, Jokerless.
struct BadgeView: View {
  enum Kind: Sendable, CaseIterable {
    case exposed, concealed, dead, east, jokerless

    var title: String {
      switch self {
      case .exposed: return "X"
      case .concealed: return "C"
      case .dead: return "Dead"
      case .east: return "East"
      case .jokerless: return "Jokerless"
      }
    }

    var spokenName: String {
      switch self {
      case .exposed: return "Exposed hand"
      case .concealed: return "Concealed hand"
      case .dead: return "Dead hand"
      case .east: return "East, the dealer"
      case .jokerless: return "Jokerless"
      }
    }
  }

  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme
  let kind: Kind

  init(_ kind: Kind) {
    self.kind = kind
  }

  var body: some View {
    HStack(spacing: 3) {
      if kind == .jokerless {
        Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
      }
      Text(kind.title)
        .tinyStyle()
    }
    .foregroundStyle(foreground)
    .padding(.horizontal, Spacing.sm)
    .padding(.vertical, 3)
    .background(background, in: Capsule())
    .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(kind.spokenName)
  }

  private var foreground: Color {
    switch kind {
    case .exposed: return theme.primary
    case .concealed, .jokerless: return theme.text
    case .dead: return theme.onPrimary
    // Gold needs dark ink in both schemes: `text` is dark in light mode, `onPrimary` is dark in dark mode.
    case .east: return colorScheme == .dark ? theme.onPrimary : theme.text
    }
  }

  private var background: Color {
    switch kind {
    case .exposed: return theme.primarySoft
    case .concealed, .jokerless: return theme.surfaceAlt
    case .dead: return theme.danger
    case .east: return theme.gold
    }
  }

  private var border: Color {
    switch kind {
    case .concealed: return theme.border
    case .jokerless: return theme.gold
    default: return .clear
    }
  }
}

private struct BadgePreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    HStack {
      ForEach(BadgeView.Kind.allCases, id: \.self) { BadgeView($0) }
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  BadgePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  BadgePreview().preferredColorScheme(.dark)
}
