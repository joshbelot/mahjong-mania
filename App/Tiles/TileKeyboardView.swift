import MahjongCore
import SwiftUI

/// Tap-to-add keyboard: Cracks 1-9, Bams 1-9, Dots 1-9, then N E W S R G 0 F J.
///
/// - `usage`: how many of each tile are already in use (rack, exposures and, in Playing mode, seen tiles).
///   A key shows a count badge when its usage is at least 1 and is disabled once it reaches `Tile.copies`.
/// - `blankLimit`: how many blanks the table has (0 hides the Blank key).
/// - `limit`: optional ceiling on the total of `usage`; once reached every key is disabled.
/// Medium keys are used when the available width allows, otherwise small ones.
struct TileKeyboardView: View {
  @Environment(\.theme) private var theme
  @State private var taps = 0

  let onAdd: (Tile) -> Void
  let usage: TileCounts
  let limit: Int?
  /// How many blanks the table plays with; 0 hides the Blank key (SPEC §17.5).
  let blankLimit: Int

  init(
    onAdd: @escaping (Tile) -> Void, usage: TileCounts = [:], limit: Int? = nil, blankLimit: Int = 0
  ) {
    self.onAdd = onAdd
    self.usage = usage
    self.limit = limit
    self.blankLimit = blankLimit
  }

  private var rows: [[Tile]] {
    let numbers = Suit.allCases.map { suit in (1...9).map { Tile.number($0, suit) } }
    var rows = numbers + [Array(Tile.allCases.suffix(9))]
    if blankLimit > 0 { rows.append([.blank]) }
    return rows
  }

  private var totalUsage: Int { usage.values.reduce(0, +) }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      keyboard(size: .medium, spacing: 4)
      keyboard(size: .medium, spacing: 0)
      keyboard(size: .small, spacing: 4)
    }
    .haptic(.selection, trigger: taps)
  }

  private func keyboard(size: TileSize, spacing: CGFloat) -> some View {
    VStack(spacing: size == .small ? 0 : 4) {
      ForEach(Array(rows.enumerated()), id: \.offset) { entry in
        HStack(spacing: spacing) {
          ForEach(entry.element, id: \.self) { tile in
            key(tile, size: size)
          }
          if entry.element == [.blank] {
            Text("Blank: a spare tile with nothing on it")
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
              .padding(.leading, Spacing.sm)
              .accessibilityHidden(true)
            Spacer(minLength: 0)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func key(_ tile: Tile, size: TileSize) -> some View {
    let used = usage[tile] ?? 0
    let reachedCopies = used >= (tile == .blank ? blankLimit : tile.copies)
    let reachedLimit = limit.map { totalUsage >= $0 } ?? false
    let disabled = reachedCopies || reachedLimit
    return Button {
      taps += 1
      onAdd(tile)
    } label: {
      TileView(tile: tile, size: size, state: disabled ? .dim : .normal)
        .padding(.vertical, size == .small ? 3 : 0)
        .overlay(alignment: .topTrailing) {
          if used >= 1 {
            Text("\(used)")
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(theme.onPrimary)
              .frame(minWidth: 16, minHeight: 16)
              .background(theme.primary, in: Capsule())
              .offset(x: 4, y: size == .small ? -1 : -4)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .zIndex(used >= 1 ? 1 : 0)
    .accessibilityValue(used >= 1 ? "\(used) in use" : "")
    .accessibilityIdentifier("key.\(tile.code)")
  }
}

private struct KeyboardPreview: View {
  @Environment(\.theme) private var theme
  @State private var tiles: [Tile] = ["1C", "1C", "1C", "1C", "5D", "J"].compactMap { Tile(code: $0) }

  var body: some View {
    VStack(spacing: Spacing.lg) {
      TileRackView(
        tiles: tiles,
        onRemove: { tile in
          if let index = tiles.firstIndex(of: tile) { tiles.remove(at: index) }
        })
      TileKeyboardView(onAdd: { tiles.append($0) }, usage: tiles.counts, limit: 14)
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  KeyboardPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  KeyboardPreview().preferredColorScheme(.dark)
}
