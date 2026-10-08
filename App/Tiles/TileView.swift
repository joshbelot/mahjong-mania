import MahjongCore
import SwiftUI

enum TileSize: Sendable, CaseIterable {
  case small, medium, large

  /// Thickness of the coloured bottom edge (the tile's back).
  static let edge: CGFloat = 3

  var width: CGFloat {
    switch self {
    case .small: return 28
    case .medium: return 40
    case .large: return 52
    }
  }

  var height: CGFloat {
    switch self {
    case .small: return 38
    case .medium: return 54
    case .large: return 70
    }
  }

  var radius: CGFloat {
    switch self {
    case .small: return 6
    case .medium: return 8
    case .large: return 10
    }
  }

  /// Font size of the numeral on number tiles.
  var numeral: CGFloat {
    switch self {
    case .small: return 15
    case .medium: return 22
    case .large: return 28
    }
  }

  /// Height of the suit glyph below the numeral.
  var glyph: CGFloat {
    switch self {
    case .small: return 12
    case .medium: return 17
    case .large: return 22
    }
  }

  /// Size of honour glyphs (winds, dragons, flower).
  var honor: CGFloat {
    switch self {
    case .small: return 20
    case .medium: return 30
    case .large: return 40
    }
  }

  /// Size of the small captions ("JOKER", the Soap zero).
  var caption: CGFloat {
    switch self {
    case .small: return 7
    case .medium: return 9.5
    case .large: return 12
    }
  }
}

enum TileState: Sendable, CaseIterable {
  case normal, dim, selected, missing
}

/// One mahjong tile drawn with SwiftUI shapes and text. Wrap in a `Button` where it is tappable.
struct TileView: View {
  @Environment(\.theme) private var theme
  let tile: Tile
  var size: TileSize = .medium
  var state: TileState = .normal

  init(tile: Tile, size: TileSize = .medium, state: TileState = .normal) {
    self.tile = tile
    self.size = size
    self.state = state
  }

  var body: some View {
    let faceHeight = size.height - TileSize.edge
    ZStack(alignment: .top) {
      if state == .missing {
        RoundedRectangle(cornerRadius: size.radius)
          .fill(theme.tileFace.opacity(0.14))
        RoundedRectangle(cornerRadius: size.radius)
          .strokeBorder(theme.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        TileFace(tile: tile, size: size)
          .frame(width: size.width, height: faceHeight)
          .opacity(0.5)
      } else {
        RoundedRectangle(cornerRadius: size.radius).fill(theme.tileEdge)
        RoundedRectangle(cornerRadius: size.radius)
          .fill(theme.tileFace)
          .frame(width: size.width, height: faceHeight)
          .overlay(TileFace(tile: tile, size: size))
          .overlay(
            RoundedRectangle(cornerRadius: size.radius)
              .strokeBorder(theme.tileEdge.opacity(0.35), lineWidth: 0.5)
              .frame(width: size.width, height: faceHeight))
      }
    }
    .frame(width: size.width, height: size.height)
    .shadow(
      color: state == .missing ? .clear : theme.tileShadow, radius: 1.5, x: 0, y: 1.5
    )
    .overlay {
      if state == .selected {
        RoundedRectangle(cornerRadius: size.radius).strokeBorder(theme.primary, lineWidth: 2)
      }
    }
    .opacity(state == .dim ? 0.4 : 1)
    .offset(y: state == .selected ? -2 : 0)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(tile.name)
    .accessibilityValue(state == .missing ? "Needed" : "")
    .accessibilityAddTraits(state == .selected ? .isSelected : [])
  }
}

/// The printed face of a tile, centred in the ivory area.
private struct TileFace: View {
  @Environment(\.theme) private var theme
  let tile: Tile
  let size: TileSize

  var body: some View {
    switch tile {
    case .number(let value, let suit):
      VStack(spacing: 0) {
        Text("\(value)")
          .font(.system(size: size.numeral, weight: .bold, design: .rounded))
          .foregroundStyle(ink(for: suit))
          .lineLimit(1)
        suitGlyph(suit)
      }
    case .wind(let wind):
      Text(wind.rawValue)
        .font(.system(size: size.honor, weight: .bold, design: .serif))
        .foregroundStyle(theme.tileInk)
    case .dragon(let dragon):
      dragonFace(dragon)
    case .flower:
      Image(systemName: "camera.macro")
        .font(.system(size: size.honor * 0.95))
        .foregroundStyle(theme.flower)
    case .joker:
      VStack(spacing: 1) {
        Image(systemName: "star.fill")
          .font(.system(size: size.honor * 0.55))
        Text("JOKER")
          .font(.system(size: size.caption, weight: .heavy))
          .tracking(-0.3)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      .foregroundStyle(theme.joker)
      .padding(.horizontal, 1)
    }
  }

  private func ink(for suit: Suit) -> Color {
    switch suit {
    case .cracks: return theme.suitC
    case .bams: return theme.suitB
    case .dots: return theme.suitD
    }
  }

  @ViewBuilder
  private func suitGlyph(_ suit: Suit) -> some View {
    switch suit {
    case .cracks:
      Text("萬")
        .font(.system(size: size.glyph, weight: .semibold))
        .foregroundStyle(theme.suitC)
    case .bams:
      BambooShape()
        .fill(theme.suitB)
        .frame(width: size.glyph * 0.5, height: size.glyph * 1.1)
    case .dots:
      DotView(color: theme.suitD)
        .frame(width: size.glyph, height: size.glyph)
    }
  }

  @ViewBuilder
  private func dragonFace(_ dragon: Dragon) -> some View {
    switch dragon {
    case .red:
      Text("中")
        .font(.system(size: size.honor, weight: .bold))
        .foregroundStyle(theme.suitC)
    case .green:
      Text("發")
        .font(.system(size: size.honor, weight: .bold))
        .foregroundStyle(theme.suitB)
    case .white:
      VStack(spacing: 2) {
        RoundedRectangle(cornerRadius: size.honor * 0.12)
          .strokeBorder(theme.suitD, lineWidth: max(1.5, size.honor / 14))
          .frame(width: size.honor * 0.6, height: size.honor * 0.8)
        Text("0")
          .font(.system(size: size.caption * 1.2, weight: .bold, design: .rounded))
          .foregroundStyle(theme.suitD)
      }
    }
  }
}

#Preview("Light") {
  TilePreviewSheet().preferredColorScheme(.light)
}

#Preview("Dark") {
  TilePreviewSheet().preferredColorScheme(.dark)
}

private struct TilePreviewSheet: View {
  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        ForEach(TileSize.allCases, id: \.self) { size in
          FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(Tile.allCases, id: \.self) { TileView(tile: $0, size: size) }
          }
        }
        HStack(spacing: Spacing.md) {
          ForEach(TileState.allCases, id: \.self) {
            TileView(tile: .number(5, .dots), size: .large, state: $0)
          }
        }
      }
      .padding(Spacing.lg)
    }
    .background(theme.bg)
  }
}
