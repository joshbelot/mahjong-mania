import MahjongCore
import SwiftUI

/// Settings → Appearance → Tile style: four ways to draw the tiles, each shown with a live preview row.
struct TileStyleView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings

  /// The sample tiles: 1 Crack, 5 Bam, 9 Dot, East, Red Dragon, Soap, Flower, Joker (and Blank when on).
  var sampleTiles: [Tile] {
    var tiles: [Tile] = [
      .number(1, .cracks), .number(5, .bams), .number(9, .dots), .wind(.east), .dragon(.red),
      .dragon(.white), .flower, .joker,
    ]
    if settings.settings.defaultRules.blanks != nil { tiles.append(.blank) }
    return tiles
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("Choose how the tiles look. It changes every tile in the app.")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
        ForEach(TileStyle.allCases, id: \.self) { style in
          option(style)
        }
      }
    }
    .navigationTitle("Tile style")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func option(_ style: TileStyle) -> some View {
    let selected = settings.settings.tileStyle == style
    return Button {
      settings.update { $0.tileStyle = style }
    } label: {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack {
          Text(style.title)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
          Spacer()
          if selected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(theme.primary)
              .accessibilityHidden(true)
          }
        }
        Text(style.summary)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.leading)
        FlowLayout(spacing: 4, lineSpacing: 6) {
          ForEach(Array(sampleTiles.enumerated()), id: \.offset) { entry in
            TileView(tile: entry.element, size: .medium)
          }
        }
        .environment(\.tileStyle, style)
        .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Spacing.lg)
      .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.lg)
          .strokeBorder(selected ? theme.primary : theme.border, lineWidth: selected ? 2 : 1))
      .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(style.title). \(style.summary)")
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("tileStyle.option.\(style.rawValue)")
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return NavigationStack { TileStyleView() }
    .environment(stores.settings)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return NavigationStack { TileStyleView() }
    .environment(stores.settings)
    .preferredColorScheme(.dark)
}
