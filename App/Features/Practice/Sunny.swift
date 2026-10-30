import MahjongCore
import SwiftUI

/// Sunny, the Practice mascot: a friendly Soap (white dragon) tile with a simple face, drawn in shapes.
/// Original artwork. Four expressions: hello (intros), thinking (hints), cheering (right answers and
/// finishes), oops (wrong answers, gentle).
enum SunnyExpression: String, CaseIterable {
  case hello, thinking, cheering, oops

  var spoken: String {
    switch self {
    case .hello: return "Sunny the tile mascot, waving hello"
    case .thinking: return "Sunny the tile mascot, thinking"
    case .cheering: return "Sunny the tile mascot, cheering"
    case .oops: return "Sunny the tile mascot, saying oops"
    }
  }
}

struct SunnyView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  var expression: SunnyExpression = .hello
  var size: CGFloat = 96
  /// A small bounce when it appears (not with Reduce Motion).
  var animated = false
  @State private var bounced = false

  private var w: CGFloat { size * 0.74 }

  var body: some View {
    ZStack {
      // The tile: a soft back edge, an ivory face and a thin frame, like a Soap tile.
      RoundedRectangle(cornerRadius: size * 0.16)
        .fill(theme.primary.opacity(0.85))
        .frame(width: w, height: size)
        .offset(y: size * 0.04)
      RoundedRectangle(cornerRadius: size * 0.16)
        .fill(theme.tileFace)
        .frame(width: w, height: size * 0.96)
        .overlay(
          RoundedRectangle(cornerRadius: size * 0.16).strokeBorder(theme.primary.opacity(0.35), lineWidth: size * 0.02))
        .offset(y: -size * 0.01)
      // The Soap frame.
      RoundedRectangle(cornerRadius: size * 0.08)
        .strokeBorder(theme.primary.opacity(0.4), lineWidth: size * 0.025)
        .frame(width: w * 0.74, height: size * 0.7)
      face
      extras
    }
    .frame(width: size * 1.3, height: size * 1.15)
    .scaleEffect(animated && !reduceMotion ? (bounced ? 1 : 0.7) : 1)
    .rotationEffect(.degrees(expression == .cheering && animated && !reduceMotion && bounced ? 0 : (expression == .cheering ? -4 : 0)))
    .onAppear {
      guard animated, !reduceMotion else { return }
      withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { bounced = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(expression.spoken)
  }

  private var ink: Color { Color(red: 0.16, green: 0.2, blue: 0.19) }

  private var face: some View {
    ZStack {
      // Eyes
      HStack(spacing: w * 0.24) {
        eye
        eye
      }
      .offset(y: -size * 0.1)
      // Cheeks
      HStack(spacing: w * 0.42) {
        Circle().fill(theme.accent.opacity(0.35)).frame(width: size * 0.12)
        Circle().fill(theme.accent.opacity(0.35)).frame(width: size * 0.12)
      }
      .offset(y: size * 0.03)
      mouth.offset(y: size * 0.13)
    }
  }

  @ViewBuilder
  private var eye: some View {
    switch expression {
    case .cheering:
      // Happy closed arcs.
      ArcShape(up: true)
        .stroke(ink, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
        .frame(width: size * 0.15, height: size * 0.08)
    case .oops:
      Circle().fill(ink).frame(width: size * 0.09)
        .overlay(alignment: .topTrailing) { Circle().fill(.white).frame(width: size * 0.03).offset(x: -size * 0.01, y: size * 0.01) }
    case .thinking:
      Circle().fill(ink).frame(width: size * 0.1)
        .overlay(alignment: .topTrailing) { Circle().fill(.white).frame(width: size * 0.035).offset(x: -size * 0.005, y: size * 0.005) }
        .offset(x: size * 0.02, y: -size * 0.02)
    case .hello:
      Circle().fill(ink).frame(width: size * 0.1)
        .overlay(alignment: .topTrailing) { Circle().fill(.white).frame(width: size * 0.035).offset(x: -size * 0.005, y: size * 0.005) }
    }
  }

  @ViewBuilder
  private var mouth: some View {
    switch expression {
    case .hello:
      ArcShape(up: false)
        .stroke(ink, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
        .frame(width: size * 0.22, height: size * 0.1)
    case .cheering:
      // An open smile.
      ArcShape(up: false, closed: true)
        .fill(ink)
        .frame(width: size * 0.25, height: size * 0.13)
    case .thinking:
      Capsule().fill(ink).frame(width: size * 0.1, height: size * 0.035).offset(x: size * 0.04)
    case .oops:
      ArcShape(up: true)
        .stroke(ink, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
        .frame(width: size * 0.16, height: size * 0.06)
        .offset(y: size * 0.03)
    }
  }

  @ViewBuilder
  private var extras: some View {
    switch expression {
    case .hello:
      // A little wave.
      Image(systemName: "hand.wave.fill")
        .font(.system(size: size * 0.24))
        .foregroundStyle(theme.gold)
        .offset(x: size * 0.52, y: -size * 0.28)
    case .thinking:
      Image(systemName: "questionmark")
        .font(.system(size: size * 0.24, weight: .bold))
        .foregroundStyle(theme.gold)
        .offset(x: size * 0.5, y: -size * 0.36)
    case .cheering:
      Image(systemName: "sparkles")
        .font(.system(size: size * 0.26))
        .foregroundStyle(theme.gold)
        .offset(x: size * 0.5, y: -size * 0.34)
      Image(systemName: "sparkle")
        .font(.system(size: size * 0.16))
        .foregroundStyle(theme.gold)
        .offset(x: -size * 0.5, y: -size * 0.3)
    case .oops:
      Image(systemName: "drop.fill")
        .font(.system(size: size * 0.14))
        .foregroundStyle(theme.primary.opacity(0.6))
        .offset(x: size * 0.36, y: -size * 0.3)
    }
  }
}

/// A smile (open downward) or a frown/arc (up) fitting its rect.
struct ArcShape: Shape {
  var up: Bool
  var closed = false

  func path(in rect: CGRect) -> Path {
    var path = Path()
    if up {
      path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
    } else {
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
      if closed { path.closeSubpath() }
    }
    return path
  }
}

/// A small group of tiles that stands for a unit, in the current tile style (SPEC §19.3).
struct UnitArt: View {
  let unit: Int
  var size: TileSize = .medium

  static func tiles(for unit: Int) -> [Tile] {
    func t(_ code: String) -> Tile { Tile(code: code) ?? .flower }
    switch unit {
    case 1: return [t("3C"), t("5B"), t("7D")]
    case 2: return [t("N"), t("E"), t("R")]
    case 3: return [t("J"), t("J"), t("5D")]
    case 4: return [t("2B"), t("2B"), t("2B"), t("J")]
    case 5: return [t("1B"), t("1D"), t("1C")]
    case 6: return [t("9C"), t("F")]
    case 7: return [t("0"), t("G"), t("R")]
    case 8: return [t("N"), t("E"), t("W")]
    case 9: return [t("6D"), t("6D"), t("6D")]
    default: return [t("J"), t("F"), t("0")]
    }
  }

  var body: some View {
    let tiles = Self.tiles(for: unit)
    HStack(spacing: -6) {
      ForEach(Array(tiles.enumerated()), id: \.offset) { entry in
        TileView(tile: entry.element, size: size)
          .rotationEffect(.degrees(Double(entry.offset - tiles.count / 2) * 5))
          .offset(y: entry.offset % 2 == 0 ? 0 : 3)
      }
    }
    .accessibilityHidden(true)
  }
}
