import MahjongCore
import SwiftUI

/// A wrapping rack of medium tiles with a "12/14" counter, a Sort toggle and Clear.
/// Tapping a tile calls `onRemove` with that tile (the caller removes one copy).
struct TileRackView: View {
  @Environment(\.theme) private var theme
  @State private var sortOn = false
  @State private var confirmClear = false

  let tiles: [Tile]
  let limit: Int
  let onRemove: (Tile) -> Void
  let onClear: (() -> Void)?

  init(
    tiles: [Tile], limit: Int = 14, onRemove: @escaping (Tile) -> Void, onClear: (() -> Void)? = nil
  ) {
    self.tiles = tiles
    self.limit = limit
    self.onRemove = onRemove
    self.onClear = onClear
  }

  private struct Entry: Identifiable {
    let tile: Tile
    let id: String
  }

  /// Tiles in display order with ids that stay stable when one copy is removed.
  private var entries: [Entry] {
    let ordered = sortOn ? tiles.sortedForDisplay() : tiles
    var seen: [Tile: Int] = [:]
    return ordered.map { tile in
      let occurrence = seen[tile, default: 0]
      seen[tile] = occurrence + 1
      return Entry(tile: tile, id: "\(tile.code)#\(occurrence)")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      header
      rack
    }
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
    .confirmationDialog("Clear all tiles?", isPresented: $confirmClear, titleVisibility: .visible) {
      Button("Clear \(tiles.count) tiles", role: .destructive) { onClear?() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var header: some View {
    HStack(spacing: Spacing.sm) {
      Text("\(tiles.count)/\(limit)")
        .font(Typography.h2)
        .monospacedDigit()
        .foregroundStyle(tiles.count > limit ? theme.danger : theme.text)
        .accessibilityLabel("\(tiles.count) of \(limit) tiles")
        .accessibilityIdentifier("rack.count")
      Spacer(minLength: Spacing.sm)
      Button {
        sortOn.toggle()
      } label: {
        Label("Sort", systemImage: "arrow.up.arrow.down")
          .font(Typography.small.weight(.semibold))
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
      }
      .buttonStyle(.plain)
      .foregroundStyle(sortOn ? theme.primary : theme.textMuted)
      .accessibilityAddTraits(sortOn ? .isSelected : [])
      .accessibilityIdentifier("rack.sort")
      if onClear != nil {
        Button {
          if tiles.count > 3 {
            confirmClear = true
          } else {
            onClear?()
          }
        } label: {
          Text("Clear")
            .font(Typography.small.weight(.semibold))
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tiles.isEmpty ? theme.textFaint : theme.danger)
        .disabled(tiles.isEmpty)
        .accessibilityIdentifier("rack.clear")
      }
    }
  }

  @ViewBuilder
  private var rack: some View {
    if tiles.isEmpty {
      Text("Tap tiles below to add them")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .frame(maxWidth: .infinity, minHeight: 54)
    } else {
      FlowLayout(spacing: 0, lineSpacing: Spacing.sm) {
        ForEach(entries) { entry in
          Button {
            withAnimation(.snappy(duration: 0.12)) { onRemove(entry.tile) }
          } label: {
            TileView(tile: entry.tile, size: .medium)
              .padding(.horizontal, 2)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityHint("Double-tap to remove")
          .accessibilityIdentifier("rack.tile.\(entry.tile.code)")
          .transition(
            .asymmetric(
              insertion: .scale(scale: 0.8).combined(with: .opacity),
              removal: .scale(scale: 0.6).combined(with: .opacity)))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct RackPreview: View {
  @Environment(\.theme) private var theme
  @State private var tiles: [Tile] = ["1C", "2C", "3C", "5D", "5D", "N", "R", "0", "F", "J", "9B", "9B"]
    .compactMap { Tile(code: $0) }

  var body: some View {
    VStack(spacing: Spacing.lg) {
      TileRackView(
        tiles: tiles,
        onRemove: { tile in
          if let index = tiles.firstIndex(of: tile) { tiles.remove(at: index) }
        },
        onClear: { tiles = [] })
      TileRackView(tiles: [], onRemove: { _ in })
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  RackPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  RackPreview().preferredColorScheme(.dark)
}
