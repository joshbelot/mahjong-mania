import MahjongCore
import SwiftUI

/// One row of the tile cheat sheet: the tiles, their name and what to know about them.
struct CheatRow: Identifiable {
  let id: String
  let name: String
  let tiles: [Tile]
  /// "Also called Characters. Red. Numbers 1 to 9."
  let detail: String
  /// "4 in a set", "8 in a set", or the size of a group.
  let copies: String

  /// VoiceOver reads each row as one sentence.
  var spoken: String { "\(name). \(detail) \(copies)." }
}

struct CheatGroup: Identifiable {
  let id: String
  let heading: String
  let rows: [CheatRow]
}

/// The single source for the Tiles cheat sheet and the Learn tab's Tile guide (SPEC §19.2).
enum TileCheatSheet {
  /// Suit facts, shared with the Tile guide's table.
  struct SuitFact {
    let name: String
    let alsoCalled: String
    let colour: String
    let example: [Tile]
    let extra: String
  }

  static let suits: [SuitFact] = [
    SuitFact(name: "Cracks", alsoCalled: "Characters", colour: "Red", example: [.number(1, .cracks), .number(5, .cracks), .number(9, .cracks)], extra: ""),
    SuitFact(name: "Bams", alsoCalled: "Bamboo", colour: "Green", example: [.number(1, .bams), .number(5, .bams), .number(9, .bams)], extra: " The 1 Bam is a bird."),
    SuitFact(name: "Dots", alsoCalled: "Circles", colour: "Blue", example: [.number(1, .dots), .number(5, .dots), .number(9, .dots)], extra: ""),
  ]

  struct DragonFact {
    let tile: Tile
    let nickname: String
    let goesWith: String
  }

  static let dragons: [DragonFact] = [
    DragonFact(tile: .dragon(.red), nickname: "Red", goesWith: "Cracks"),
    DragonFact(tile: .dragon(.green), nickname: "Green", goesWith: "Bams"),
    DragonFact(tile: .dragon(.white), nickname: "Soap, or zero", goesWith: "Dots"),
  ]

  static let groups: [(name: String, size: Int)] = [
    ("Single", 1), ("Pair", 2), ("Pung", 3), ("Kong", 4), ("Quint", 5), ("Sextet", 6),
  ]

  static func groups(blanks: Bool) -> [CheatGroup] {
    var result: [CheatGroup] = []
    result.append(
      CheatGroup(
        id: "suits", heading: "Suits",
        rows: suits.map {
          CheatRow(
            id: $0.name, name: $0.name, tiles: $0.example,
            detail: "Also called \($0.alsoCalled). \($0.colour). Numbers 1 to 9.\($0.extra)", copies: "4 of each number, 36 in a suit")
        }))
    result.append(
      CheatGroup(
        id: "winds", heading: "Winds",
        rows: [
          CheatRow(
            id: "winds", name: "Winds", tiles: [.wind(.north), .wind(.east), .wind(.west), .wind(.south)],
            detail: "North, East, West and South.", copies: "4 of each in a set")
        ]))
    result.append(
      CheatGroup(
        id: "dragons", heading: "Dragons",
        rows: dragons.map { fact in
          CheatRow(
            id: fact.tile.code, name: fact.tile.name, tiles: [fact.tile],
            detail: "Goes with \(fact.goesWith)."
              + (fact.tile == .dragon(.white) ? " Soap also counts as zero in year hands." : ""),
            copies: "4 in a set")
        }))
    result.append(
      CheatGroup(
        id: "flowers", heading: "Flowers",
        rows: [
          CheatRow(
            id: "flowers", name: "Flowers", tiles: [.flower],
            detail: "All eight are interchangeable, whatever picture they show.", copies: "8 in a set")
        ]))
    result.append(
      CheatGroup(
        id: "jokers", heading: "Jokers",
        rows: [
          CheatRow(
            id: "jokers", name: "Jokers", tiles: [.joker],
            detail: "Stand in for any tile, but only in sets of 3 or more. A joker can never be passed in the Charleston.",
            copies: "8 in a set")
        ]))
    if blanks {
      result.append(
        CheatGroup(
          id: "blanks", heading: "Blanks",
          rows: [
            CheatRow(
              id: "blanks", name: "Blanks", tiles: [.blank],
              detail: "Spare tiles your table adds. A blank is never part of a hand and can be swapped for a discarded tile.",
              copies: "As many as your rule book says")
          ]))
    }
    result.append(
      CheatGroup(
        id: "sets", heading: "Sets",
        rows: groups.map { group in
          CheatRow(
            id: group.name, name: group.name, tiles: Array(repeating: .number(5, .dots), count: group.size),
            detail: group.size == 1 ? "One tile on its own." : "\(group.size) of the same tile.",
            copies: group.size >= 3 ? "Jokers may join" : "No jokers")
        }))
    return result
  }
}

/// The sheet: tiles in the current tile style, grouped, one VoiceOver element per row.
struct TileCheatSheetView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(SettingsStore.self) private var settings

  private var blanksOn: Bool {
    settings.settings.defaultRules.rules.first { $0.id == RuleID.blanks }?.isEnabled == true
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          ForEach(TileCheatSheet.groups(blanks: blanksOn)) { group in
            SectionCard(group.heading) {
              VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(group.rows) { row in
                  CheatRowView(row: row)
                  if row.id != group.rows.last?.id { Divider() }
                }
              }
            }
          }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
      }
      .background(theme.bg.ignoresSafeArea())
      .navigationTitle("Tiles")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }.accessibilityIdentifier("cheat.done")
        }
      }
    }
    .accessibilityIdentifier("cheat.sheet")
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

private struct CheatRowView: View {
  @Environment(\.theme) private var theme
  let row: CheatRow

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      FlowLayout(spacing: 3, lineSpacing: 4) {
        ForEach(Array(row.tiles.enumerated()), id: \.offset) { entry in
          TileView(tile: entry.element, size: .small)
        }
      }
      Text(row.name)
        .font(Typography.body.weight(.semibold))
        .foregroundStyle(theme.text)
      Text(row.detail)
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      Text(row.copies)
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(row.spoken)
    .accessibilityIdentifier("cheat.row.\(row.id)")
  }
}

/// The "Tiles" button that opens the cheat sheet. Shown in the lesson bar, the Practice and Helper headers
/// and on Learn; opening it never costs anything.
struct TilesButton: View {
  enum Style { case icon, label }
  @Environment(\.theme) private var theme
  @State private var shown = false
  var style = Style.icon

  var body: some View {
    Button {
      shown = true
    } label: {
      switch style {
      case .icon:
        Image(systemName: "rectangle.grid.3x2")
          .font(.headline)
          .foregroundStyle(theme.primary)
          .frame(width: 44, height: 44)
      case .label:
        Label("Tiles", systemImage: "rectangle.grid.3x2")
          .font(Typography.body.weight(.medium))
          .foregroundStyle(theme.primary)
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
          .background(theme.surface, in: Capsule())
          .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
      }
    }
    .accessibilityLabel("Tiles")
    .accessibilityHint("Opens a cheat sheet of every tile")
    .accessibilityIdentifier("tiles.button")
    .sheet(isPresented: $shown) { TileCheatSheetView() }
  }
}
