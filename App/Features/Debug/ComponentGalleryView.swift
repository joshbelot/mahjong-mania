#if DEBUG
  import MahjongCore
  import SwiftUI

  /// Debug-only screen showing every reusable component and tile state (Settings > Component gallery).
  struct ComponentGalleryView: View {
    @Environment(\.theme) private var theme

    @State private var rack: [Tile] = GallerySamples.rackTiles
    @State private var selectedChip = "25"
    @State private var selectedPlayer = 1
    @State private var assist = "Peek"
    @State private var points = 25
    @State private var showSuitLetters = false

    var body: some View {
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          buttonsCard
          controlsCard
          identityCard
          rowsCard
          tilesCard(title: "Tiles: large", size: .large)
          tilesCard(title: "Tiles: medium", size: .medium)
          tilesCard(title: "Tiles: small", size: .small)
          statesCard
          rackCard
          compactPatternsCard
          tilePatternsCard
        }
      }
      .navigationTitle("Component gallery")
      .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Cards

    private var buttonsCard: some View {
      SectionCard("Buttons") {
        VStack(spacing: Spacing.md) {
          Button("Primary") {}.buttonStyle(PrimaryButton(.primary))
          Button("Secondary") {}.buttonStyle(PrimaryButton(.secondary))
          Button("Ghost") {}.buttonStyle(PrimaryButton(.ghost))
          Button("Destructive") {}.buttonStyle(PrimaryButton(.destructive))
          Button("Large primary") {}.buttonStyle(PrimaryButton(.primary, size: .large))
          Button("Large secondary") {}.buttonStyle(PrimaryButton(.secondary, size: .large))
          Button("Disabled") {}.buttonStyle(PrimaryButton(.primary)).disabled(true)
        }
      }
    }

    private var controlsCard: some View {
      SectionCard("Chips, picker, stepper") {
        VStack(alignment: .leading, spacing: Spacing.md) {
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(["25", "30", "35", "40", "45"], id: \.self) { value in
              ChipView(value, isSelected: selectedChip == value) { selectedChip = value }
            }
          }
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(Array(["Alex", "Bea", "Cy", "Dana"].enumerated()), id: \.offset) { entry in
              ChipView(
                entry.element, isSelected: selectedPlayer == entry.offset,
                tint: PlayerPalette.color(at: entry.offset)
              ) { selectedPlayer = entry.offset }
            }
          }
          SegmentedPicker("Assist level", selection: $assist, options: ["Off", "Peek", "Coach"]) {
            $0
          }
          StepperField("Points", value: $points, step: 5, range: 0...500, unit: "pts")
          Toggle("Show suit letters", isOn: $showSuitLetters)
            .tint(theme.primary)
            .frame(minHeight: 44)
        }
      }
    }

    private var identityCard: some View {
      SectionCard("Avatars, badges, amounts") {
        VStack(alignment: .leading, spacing: Spacing.md) {
          HStack {
            ForEach(0..<8, id: \.self) { index in
              AvatarView(name: GallerySamples.names[index], colorIndex: index, size: 34)
            }
          }
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(BadgeView.Kind.allCases, id: \.self) { BadgeView($0) }
          }
          HStack(spacing: Spacing.lg) {
            PointsText(75)
            PointsText(-25)
            PointsText(0)
            MoneyText(cents: 125)
            MoneyText(cents: -50)
          }
        }
      }
    }

    private var rowsCard: some View {
      SectionCard("List rows and empty state") {
        VStack(alignment: .leading, spacing: 0) {
          ListRowView("Bea", subtitle: "12 games") {
            Image(systemName: "chevron.right").foregroundStyle(theme.textFaint)
          }
          Divider().overlay(theme.border)
          ListRowView("East") { BadgeView(.east) }
          Divider().overlay(theme.border)
          ListRowView("Net points") { PointsText(120) }
          EmptyStateView(
            "No games yet", systemImage: "dice", message: "Start a game night to see it here.",
            actionTitle: "New game night"
          ) {}
          .frame(height: 260)
        }
      }
    }

    private func tilesCard(title: String, size: TileSize) -> some View {
      SectionCard(title) {
        FlowLayout(spacing: 4, lineSpacing: 6) {
          ForEach(Tile.allCases, id: \.self) { TileView(tile: $0, size: size) }
        }
      }
    }

    private var statesCard: some View {
      SectionCard("Tile states") {
        VStack(alignment: .leading, spacing: Spacing.md) {
          ForEach(
            [Tile.number(5, .dots), Tile.number(8, .bams), Tile.dragon(.white)], id: \.self
          ) { tile in
            HStack(spacing: Spacing.md) {
              ForEach(TileState.allCases, id: \.self) { state in
                VStack(spacing: Spacing.xs) {
                  TileView(tile: tile, size: .large, state: state)
                  Text(String(describing: state)).font(Typography.small).foregroundStyle(theme.textMuted)
                }
              }
            }
          }
        }
      }
    }

    private var rackCard: some View {
      SectionCard("Rack and keyboard") {
        VStack(spacing: Spacing.md) {
          TileRackView(
            tiles: rack,
            onRemove: { tile in
              if let index = rack.firstIndex(of: tile) { rack.remove(at: index) }
            },
            onClear: { rack = [] })
          TileKeyboardView(
            onAdd: { tile in withAnimation(.snappy(duration: 0.12)) { rack.append(tile) } },
            usage: rack.counts, limit: 14)
        }
      }
    }

    private var compactPatternsCard: some View {
      SectionCard("Patterns: compact") {
        VStack(alignment: .leading, spacing: Spacing.md) {
          ForEach(GallerySamples.lines, id: \.id) { line in
            VStack(alignment: .leading, spacing: 2) {
              Text(line.displayName).font(Typography.small).foregroundStyle(theme.textMuted)
              if let variant = line.variants.first {
                HandPatternView(
                  variant: variant, line: line, showSuitLetters: showSuitLetters, mode: .compact)
              }
            }
          }
        }
      }
    }

    private var tilePatternsCard: some View {
      SectionCard("Patterns: tiles") {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          ForEach(GallerySamples.results, id: \.line.id) { result in
            VStack(alignment: .leading, spacing: 2) {
              Text(result.line.displayName).font(Typography.small).foregroundStyle(theme.textMuted)
              HandPatternView(
                variant: result.line.variants[
                  min(result.best.target.variantIndex, result.line.variants.count - 1)],
                line: result.line, evaluation: result.best, mode: .tiles)
            }
          }
          if let line = GallerySamples.line(named: "Wind Quints"), let variant = line.variants.first {
            VStack(alignment: .leading, spacing: 2) {
              Text("\(line.displayName) (no rack)").font(Typography.small)
                .foregroundStyle(theme.textMuted)
              HandPatternView(variant: variant, line: line, mode: .tiles)
            }
          }
        }
      }
    }
  }

  /// Hard-coded sample data for the gallery.
  private enum GallerySamples {
    static let names = ["Alex Kim", "Bea", "Cy Lo", "Dana", "Eli", "Fay", "Gus", "Hana"]

    static let rackTiles: [Tile] = [
      "1C", "2C", "3C", "5D", "5D", "N", "R", "0", "F", "J", "9B", "9B"
    ].compactMap { Tile(code: $0) }

    static let lineNames = [
      "Year Kongs", "Compass Year", "Three Plus Four", "Wind Quints", "Pair Ladder", "Odd Singles",
    ]

    static func line(named name: String) -> CardLine? {
      PracticeCard.card.lines.first { $0.name == name }
    }

    static let lines: [CardLine] = lineNames.compactMap { line(named: $0) }

    static let analyzer = Analyzer(card: PracticeCard.card)

    /// A 13-tile rack that is part-way to a few lines, including one joker.
    static let sampleRack: [Tile] = [
      "F", "F", "2C", "2C", "2C", "4C", "4C", "4C", "4C", "6C", "6C", "6C", "J",
    ].compactMap { Tile(code: $0) }

    static let results: [LineResult] = Array(
      analyzer.analyze(PlayerView(rack: sampleRack)).prefix(3))
  }

  #Preview("Light") {
    NavigationStack { ComponentGalleryView() }.preferredColorScheme(.light)
  }

  #Preview("Dark") {
    NavigationStack { ComponentGalleryView() }.preferredColorScheme(.dark)
  }
#endif
