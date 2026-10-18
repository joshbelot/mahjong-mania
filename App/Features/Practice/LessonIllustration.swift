import MahjongCore
import SwiftUI

/// A few labelled tiles shown on a lesson's intro card, so the lesson teaches before it asks.
struct LessonIllustration: View {
  @Environment(\.theme) private var theme
  let nodeID: String

  struct Example: Identifiable {
    let id = UUID()
    let caption: String
    let tiles: [Tile]
  }

  static func examples(for nodeID: String) -> [Example] {
    func tiles(_ codes: String...) -> [Tile] { codes.compactMap { Tile(code: $0) } }
    switch nodeID {
    case "u1l1":
      return [
        Example(caption: "Crack", tiles: tiles("3C")), Example(caption: "Bam", tiles: tiles("5B")),
        Example(caption: "Dot", tiles: tiles("7D")),
      ]
    case "u1l2":
      return [
        Example(caption: "Winds", tiles: tiles("N", "E", "W", "S")),
        Example(caption: "Dragons", tiles: tiles("R", "G")),
      ]
    case "u1l3":
      return [
        Example(caption: "Flower", tiles: tiles("F")), Example(caption: "Joker", tiles: tiles("J")),
        Example(caption: "Soap", tiles: tiles("0")),
      ]
    case "u2l1":
      return [
        Example(caption: "Single", tiles: tiles("5D")), Example(caption: "Pair", tiles: tiles("5D", "5D")),
        Example(caption: "Pung", tiles: tiles("5D", "5D", "5D")),
        Example(caption: "Kong", tiles: tiles("5D", "5D", "5D", "5D")),
      ]
    case "u3l2":
      return [
        Example(caption: "Legal: in a Pung", tiles: tiles("7B", "7B", "J")),
        Example(caption: "Not legal: in a Pair", tiles: tiles("7B", "J")),
      ]
    default:
      return []
    }
  }

  var body: some View {
    let examples = Self.examples(for: nodeID)
    if !examples.isEmpty {
      FlowLayout(spacing: Spacing.lg, lineSpacing: Spacing.lg) {
        ForEach(examples) { example in
          VStack(spacing: Spacing.xs) {
            HStack(spacing: 3) {
              ForEach(Array(example.tiles.enumerated()), id: \.offset) { entry in
                TileView(tile: entry.element, size: example.tiles.count > 2 ? .small : .medium)
              }
            }
            Text(example.caption)
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.textMuted)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Spacing.lg)
      .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
      .accessibilityElement(children: .combine)
    }
  }
}
