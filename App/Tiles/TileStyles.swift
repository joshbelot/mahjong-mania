import MahjongCore
import SwiftUI

extension TileStyle {
  /// The colour of a tile's face. Only Modern changes it: number tiles take their suit's colour and
  /// honours sit on a neutral face.
  func faceColor(for tile: Tile, theme: Theme) -> Color {
    guard self == .modern else { return theme.tileFace }
    switch tile {
    case .number(_, let suit):
      switch suit {
      case .cracks: return theme.suitC
      case .bams: return theme.suitB
      case .dots: return theme.suitD
      }
    case .blank: return theme.tileFace
    default: return theme.modernNeutral
    }
  }
}

/// Draws a tile's face in the chosen style. All artwork is original, drawn in SwiftUI.
struct StyledTileFace: View {
  let tile: Tile
  let size: TileSize
  let style: TileStyle

  var body: some View {
    switch style {
    case .classic: ClassicTileFace(tile: tile, size: size)
    case .traditional: TraditionalTileFace(tile: tile, size: size)
    case .largePrint: LargePrintTileFace(tile: tile, size: size)
    case .modern: ModernTileFace(tile: tile, size: size)
    }
  }
}

// MARK: - Traditional

/// Like a real set: cracks show a Chinese numeral over 萬, dots and bams show pips and sticks as on
/// physical tiles, winds and dragons show their characters.
private struct TraditionalTileFace: View {
  @Environment(\.theme) private var theme
  let tile: Tile
  let size: TileSize

  private static let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

  var body: some View {
    switch tile {
    case .number(let value, let suit):
      switch suit {
      case .cracks:
        VStack(spacing: 0) {
          Text(Self.numerals[value - 1])
            .font(.system(size: size.numeral * 0.95, weight: .bold, design: .serif))
            .foregroundStyle(theme.tileInk)
          Text("萬")
            .font(.system(size: size.glyph * 1.1, weight: .bold))
            .foregroundStyle(theme.suitC)
        }
      case .dots:
        pips(value, ink: theme.suitD, stick: false)
      case .bams:
        pips(value, ink: theme.suitB, stick: true)
      }
    case .wind(let wind):
      ZStack(alignment: .bottomTrailing) {
        Text(Self.character(for: wind))
          .font(.system(size: size.honor * 0.95, weight: .bold, design: .serif))
          .foregroundStyle(theme.tileInk)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        Text(wind.rawValue)
          .font(.system(size: size.caption * 1.1, weight: .heavy, design: .rounded))
          .foregroundStyle(theme.textMuted)
          .padding(.trailing, 3)
          .padding(.bottom, 1)
      }
    case .dragon(let dragon):
      switch dragon {
      case .red:
        Text("中").font(.system(size: size.honor, weight: .bold)).foregroundStyle(theme.suitC)
      case .green:
        Text("發").font(.system(size: size.honor, weight: .bold)).foregroundStyle(theme.suitB)
      case .white:
        RoundedRectangle(cornerRadius: size.honor * 0.1)
          .strokeBorder(theme.suitD, lineWidth: max(2, size.honor / 9))
          .frame(width: size.honor * 0.7, height: size.honor * 0.95)
      }
    case .flower:
      Blossom(color: theme.flower, centre: theme.joker)
        .frame(width: size.honor * 0.95, height: size.honor * 0.95)
    case .joker:
      Text("JOKER")
        .font(.system(size: size.caption * 1.35, weight: .heavy))
        .tracking(-0.3)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(theme.joker)
        .padding(.horizontal, 1)
    case .blank:
      Color.clear
    }
  }

  private static func character(for wind: Wind) -> String {
    switch wind {
    case .east: return "東"
    case .south: return "南"
    case .west: return "西"
    case .north: return "北"
    }
  }

  /// Pips (dots) or sticks (bams) arranged as on a physical tile, with a tiny index numeral so the
  /// count can be read at a glance, also at the small size.
  private func pips(_ count: Int, ink: Color, stick: Bool) -> some View {
    GeometryReader { geo in
      let points = PipLayout.points(for: count)
      let unit = min(geo.size.width, geo.size.height)
      let scale: CGFloat = count == 1 ? 2.0 : (count >= 7 ? 0.74 : 1.0)
      let d = unit * 0.25 * scale
      ZStack {
        ForEach(Array(points.enumerated()), id: \.offset) { entry in
          pip(stick: stick, ink: ink, centre: stick && count == 5 && entry.offset == 4, d: d)
            // Nudged right and down so the pips clear the index numeral in the corner.
            .position(
              x: (0.14 + 0.86 * entry.element.x) * geo.size.width,
              y: (0.12 + 0.88 * entry.element.y) * geo.size.height)
        }
        Text("\(count)")
          .font(.system(size: size.caption * 1.15, weight: .bold, design: .rounded))
          .foregroundStyle(ink)
          .position(x: size.caption * 0.9, y: size.caption * 0.95)
      }
    }
  }

  @ViewBuilder
  private func pip(stick: Bool, ink: Color, centre: Bool, d: CGFloat) -> some View {
    if stick {
      RoundedRectangle(cornerRadius: d * 0.22)
        .fill(centre ? theme.suitC : ink)
        .frame(width: d * 0.62, height: d * 1.45)
    } else {
      Circle()
        .strokeBorder(ink, lineWidth: max(1.2, d * 0.3))
        .frame(width: d, height: d)
    }
  }
}

/// Where the pips sit on a tile, as fractions of the face (SPEC §17.6: "as on physical tiles").
enum PipLayout {
  static func points(for count: Int) -> [CGPoint] {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    switch count {
    case 1: return [p(0.5, 0.52)]
    case 2: return [p(0.5, 0.28), p(0.5, 0.74)]
    case 3: return [p(0.3, 0.24), p(0.5, 0.52), p(0.7, 0.8)]
    case 4: return [p(0.3, 0.3), p(0.7, 0.3), p(0.3, 0.74), p(0.7, 0.74)]
    case 5: return [p(0.3, 0.3), p(0.7, 0.3), p(0.3, 0.74), p(0.7, 0.74), p(0.5, 0.52)]
    case 6: return [p(0.3, 0.24), p(0.7, 0.24), p(0.3, 0.52), p(0.7, 0.52), p(0.3, 0.8), p(0.7, 0.8)]
    case 7:
      return [
        p(0.5, 0.2), p(0.3, 0.46), p(0.7, 0.46), p(0.3, 0.64), p(0.7, 0.64), p(0.3, 0.82), p(0.7, 0.82),
      ]
    case 8:
      return [
        p(0.3, 0.2), p(0.7, 0.2), p(0.3, 0.4), p(0.7, 0.4), p(0.3, 0.6), p(0.7, 0.6), p(0.3, 0.8),
        p(0.7, 0.8),
      ]
    default:
      return [
        p(0.25, 0.24), p(0.5, 0.24), p(0.75, 0.24), p(0.25, 0.52), p(0.5, 0.52), p(0.75, 0.52),
        p(0.25, 0.8), p(0.5, 0.8), p(0.75, 0.8),
      ]
    }
  }
}

/// A simple five-petal blossom.
private struct Blossom: View {
  let color: Color
  let centre: Color

  var body: some View {
    GeometryReader { geo in
      let s = min(geo.size.width, geo.size.height)
      ZStack {
        ForEach(0..<5, id: \.self) { index in
          Ellipse()
            .fill(color)
            .frame(width: s * 0.34, height: s * 0.5)
            .offset(y: -s * 0.2)
            .rotationEffect(.degrees(Double(index) * 72))
        }
        Circle().fill(centre).frame(width: s * 0.22, height: s * 0.22)
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
  }
}

// MARK: - Large print

/// High contrast for low vision: a big numeral or letter, the suit spelled out in the suit colour,
/// no fine detail.
private struct LargePrintTileFace: View {
  @Environment(\.theme) private var theme
  let tile: Tile
  let size: TileSize

  private var big: CGFloat { size.numeral * 1.55 }
  private var word: CGFloat { size.caption * 1.25 }

  var body: some View {
    switch tile {
    case .number(let value, let suit):
      stack("\(value)", caption: Self.word(for: suit), ink: ink(for: suit))
    case .wind(let wind):
      Text(wind.rawValue)
        .font(.system(size: size.honor * 1.35, weight: .black, design: .serif))
        .foregroundStyle(theme.tileInk)
    case .dragon(let dragon):
      switch dragon {
      case .red: stack("R", caption: "RED", ink: theme.suitC)
      case .green: stack("G", caption: "GREEN", ink: theme.suitB)
      case .white: stack("0", caption: "SOAP", ink: theme.suitD)
      }
    case .flower: stack("F", caption: "FLOWER", ink: theme.flower)
    case .joker: stack("J", caption: "JOKER", ink: theme.joker)
    case .blank: Color.clear
    }
  }

  private func stack(_ letter: String, caption: String, ink: Color) -> some View {
    VStack(spacing: 0) {
      Text(letter)
        .font(.system(size: big, weight: .black, design: .rounded))
        .foregroundStyle(ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(caption)
        .font(.system(size: word, weight: .heavy, design: .rounded))
        .foregroundStyle(ink)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .padding(.horizontal, 1)
  }

  private func ink(for suit: Suit) -> Color {
    switch suit {
    case .cracks: return theme.suitC
    case .bams: return theme.suitB
    case .dots: return theme.suitD
    }
  }

  private static func word(for suit: Suit) -> String {
    switch suit {
    case .cracks: return "CRAK"
    case .bams: return "BAM"
    case .dots: return "DOT"
    }
  }
}

// MARK: - Modern

/// Flat, colour-blocked: each suit has a tinted face, a white numeral and a simple shape. Honours use
/// the Classic art on a neutral face.
private struct ModernTileFace: View {
  @Environment(\.theme) private var theme
  let tile: Tile
  let size: TileSize

  var body: some View {
    switch tile {
    case .number(let value, let suit):
      VStack(spacing: size == .small ? 1 : 3) {
        Text("\(value)")
          .font(.system(size: size.numeral * 1.2, weight: .heavy, design: .rounded))
          .foregroundStyle(theme.modernOnColor)
          .lineLimit(1)
        mark(suit)
          .frame(width: size.glyph * 0.85, height: size.glyph * 0.85)
      }
    case .blank:
      Color.clear
    default:
      ClassicTileFace(tile: tile, size: size)
    }
  }

  @ViewBuilder
  private func mark(_ suit: Suit) -> some View {
    switch suit {
    case .cracks: RoundedRectangle(cornerRadius: 2).fill(theme.modernOnColor)
    case .bams: TriangleShape().fill(theme.modernOnColor)
    case .dots: Circle().fill(theme.modernOnColor)
    }
  }
}

private struct TriangleShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
