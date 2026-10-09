import MahjongCore
import SwiftUI

/// Collapsible "Seen tiles" tracker (Playing mode): tap a tile each time you see another one go by,
/// touch and hold to take one back. The count feeds dead-hand detection.
struct SeenTilesSection: View {
  @Environment(\.theme) private var theme
  @Environment(HelperStore.self) private var helper

  @State private var expanded = false
  @State private var taps = 0

  private var seenTotal: Int { helper.seen.values.reduce(0, +) }

  private var rows: [[Tile]] {
    let numbers = Suit.allCases.map { suit in (1...9).map { Tile.number($0, suit) } }
    return numbers + [Array(Tile.allCases.suffix(9))]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      Button {
        withAnimation(.smooth(duration: 0.2)) { expanded.toggle() }
      } label: {
        HStack(spacing: Spacing.sm) {
          Text("Seen tiles")
            .font(Typography.h2)
            .foregroundStyle(theme.text)
          Spacer(minLength: Spacing.sm)
          Text("\(seenTotal) seen")
            .font(Typography.small.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(theme.textMuted)
            .accessibilityIdentifier("seen.count")
          Image(systemName: "chevron.down")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.textMuted)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Seen tiles, \(seenTotal) seen")
      .accessibilityHint(expanded ? "Double-tap to collapse" : "Double-tap to expand")
      .accessibilityIdentifier("seen.toggle")

      if expanded {
        Text("Tap a tile each time you see another one discarded or exposed. Touch and hold to take one back.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        keyboard
        if seenTotal > 0 {
          Button("Clear seen tiles") {
            withAnimation(.smooth(duration: 0.2)) { helper.clearSeen() }
          }
          .buttonStyle(PrimaryButton(.ghost))
          .accessibilityIdentifier("seen.clear")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, Spacing.lg)
    .padding(.vertical, Spacing.sm)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
    .haptic(.selection, trigger: taps)
  }

  private var keyboard: some View {
    VStack(spacing: 4) {
      ForEach(Array(rows.enumerated()), id: \.offset) { row in
        HStack(spacing: 2) {
          ForEach(row.element, id: \.self) { tile in
            key(tile)
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func key(_ tile: Tile) -> some View {
    let count = helper.seen[tile] ?? 0
    let full = !helper.canAdd(tile)
    return TileView(tile: tile, size: .small, state: full && count == 0 ? .dim : .normal)
      .overlay(alignment: .topTrailing) {
        if count >= 1 {
          Text("\(count)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(theme.onPrimary)
            .frame(minWidth: 16, minHeight: 16)
            .background(theme.primary, in: Capsule())
            .offset(x: 4, y: -4)
        }
      }
      .padding(.vertical, 3)
      .contentShape(Rectangle())
      .onTapGesture {
        if helper.canAdd(tile) {
          taps += 1
          withAnimation(.snappy(duration: 0.12)) { helper.incrementSeen(tile) }
        }
      }
      .onLongPressGesture(minimumDuration: 0.4) {
        taps += 1
        withAnimation(.snappy(duration: 0.12)) { helper.decrementSeen(tile) }
      }
      .zIndex(count >= 1 ? 1 : 0)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(tile.name)
      .accessibilityValue(count >= 1 ? "\(count) seen" : "")
      .accessibilityHint("Double-tap to add one seen. Use the actions to remove one.")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction {
        if helper.canAdd(tile) { helper.incrementSeen(tile) }
      }
      .accessibilityAction(named: "Remove one seen") { helper.decrementSeen(tile) }
      .accessibilityIdentifier("seen.key.\(tile.code)")
  }
}
