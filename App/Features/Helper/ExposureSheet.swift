import MahjongCore
import SwiftUI

/// Spoken description of an exposed group, e.g. "Pung of 6 Dot, 1 joker".
func exposureDescription(_ exposure: Exposure) -> String {
  let naturals = exposure.tiles.filter { $0 != .joker }
  let jokers = exposure.tiles.count - naturals.count
  let name = naturals.first?.name ?? "Joker"
  var text = "\(HelperText.groupNoun(exposure.tiles.count).capitalized) of \(name)"
  if jokers > 0 { text += ", \(jokers) \(jokers == 1 ? "joker" : "jokers")" }
  return text
}

/// A row of exposed sets (each a button that removes it) followed by a "+ Add a set" button.
struct ExposuresRow: View {
  @Environment(\.theme) private var theme

  let exposures: [Exposure]
  let identifierPrefix: String
  let onRemove: (Int) -> Void
  let onAdd: () -> Void

  var body: some View {
    FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
      ForEach(Array(exposures.enumerated()), id: \.offset) { entry in
        Button {
          withAnimation(.snappy(duration: 0.12)) { onRemove(entry.offset) }
        } label: {
          HStack(spacing: 1) {
            ForEach(Array(entry.element.tiles.enumerated()), id: \.offset) { tile in
              TileView(tile: tile.element, size: .small)
            }
          }
          .padding(.horizontal, Spacing.sm)
          .frame(minHeight: 44)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .overlay(
            RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1)
          )
          .contentShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exposureDescription(entry.element))
        .accessibilityHint("Double-tap to remove this set")
        .accessibilityIdentifier("\(identifierPrefix).exposure.\(entry.offset)")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
      }
      Button(action: onAdd) {
        Label("Add a set", systemImage: "plus")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.primary)
          .padding(.horizontal, Spacing.md)
          .frame(minHeight: 44)
          .background(theme.primarySoft, in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Add an exposed set")
      .accessibilityIdentifier("\(identifierPrefix).add")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Pick a tile, a size (3 to 6) and how many of the group are jokers, then add it.
struct ExposureSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss

  let title: String
  /// Copies of each tile already accounted for elsewhere (rack, exposures, seen tiles).
  let usage: TileCounts
  let onAdd: (Exposure) -> Void

  @State private var tile: Tile?
  @State private var size = 3
  @State private var jokers = 0

  private static let sizes = [3, 4, 5, 6]

  /// "3 · Pung": the number first, the table word second.
  static func sizeTitle(_ count: Int) -> String {
    "\(count) \u{00B7} \(HelperText.groupNoun(count).capitalized)"
  }

  private func step(_ text: String) -> some View {
    Text(text)
      .font(Typography.h2)
      .foregroundStyle(theme.text)
      .accessibilityAddTraits(.isHeader)
  }

  private var naturals: Int { max(0, size - jokers) }

  /// Why the group cannot be added, or nil when it can.
  private var problem: String? {
    guard let tile else { return "Pick a tile first." }
    let available = tile.copies - (usage[tile] ?? 0)
    if naturals > available {
      return "Only \(max(0, available)) \(tile.name) left to expose."
    }
    let jokersLeft = Tile.joker.copies - (usage[.joker] ?? 0)
    if jokers > jokersLeft { return "Only \(max(0, jokersLeft)) jokers left." }
    return nil
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          step("Which tile?")
          TileKeyboardView(
            onAdd: { picked in
              // Jokers are added with the joker count below, not picked as the tile.
              if picked != .joker { tile = picked }
            }, usage: usage)
          VStack(alignment: .leading, spacing: Spacing.sm) {
            step("How many in the set?")
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
              ForEach(Self.sizes, id: \.self) { count in
                ChipView(Self.sizeTitle(count), isSelected: size == count) { size = count }
                  .accessibilityIdentifier("exposure.size.\(count)")
              }
            }
            .accessibilityIdentifier("exposure.size")
          }
          VStack(alignment: .leading, spacing: Spacing.sm) {
            step("How many of them are jokers?")
            SegmentedPicker("Jokers", selection: $jokers, options: Array(0..<size)) { "\($0)" }
              .accessibilityIdentifier("exposure.jokers")
          }
          preview
        }
        .padding(Spacing.lg)
      }
      .background(theme.bg)
      .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("exposure.cancel")
        }
      }
      .onChange(of: size) { _, newSize in
        if jokers > newSize - 1 { jokers = newSize - 1 }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  @ViewBuilder
  private var preview: some View {
    if let tile {
      HStack(spacing: 2) {
        ForEach(0..<naturals, id: \.self) { _ in TileView(tile: tile, size: .medium) }
        ForEach(0..<jokers, id: \.self) { _ in TileView(tile: .joker, size: .medium) }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        exposureDescription(Exposure(tiles: exposureTiles(for: tile))))
      .accessibilityIdentifier("exposure.preview")
    }
  }

  private func exposureTiles(for tile: Tile) -> [Tile] {
    Array(repeating: tile, count: naturals) + Array(repeating: Tile.joker, count: jokers)
  }

  private var addBar: some View {
    VStack(spacing: Spacing.xs) {
      if let problem, tile != nil {
        Text(problem)
          .font(Typography.small)
          .foregroundStyle(theme.danger)
      }
      Button {
        if let tile, problem == nil {
          onAdd(Exposure(tiles: exposureTiles(for: tile)))
          dismiss()
        }
      } label: {
        Text("Add")
      }
      .buttonStyle(PrimaryButton(.primary, size: .large))
      .disabled(problem != nil)
      .accessibilityIdentifier("exposure.confirm")
    }
    .padding(Spacing.lg)
    .background(theme.surface)
  }
}

#Preview("Light") {
  ExposureSheet(title: "Add an exposed set", usage: [.number(6, .dots): 1]) { _ in }
    .environment(\.theme, Theme.standard)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  ExposureSheet(title: "Add an exposed set", usage: [:]) { _ in }
    .environment(\.theme, Theme.standard)
    .preferredColorScheme(.dark)
}

/// Explains what an exposed set is, with a drawn example (SPEC §17.2).
struct ExposedSetInfoSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          Text("An exposed set is a group of 3 or more matching tiles that you took from another player's discard and laid face up in front of your rack.")
            .font(Typography.body)
            .foregroundStyle(theme.text)
          VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Example")
              .font(Typography.h2)
              .foregroundStyle(theme.text)
              .accessibilityAddTraits(.isHeader)
            HStack(spacing: 2) {
              TileView(tile: .number(6, .dots), size: .medium)
              TileView(tile: .number(6, .dots), size: .medium)
              TileView(tile: .joker, size: .medium)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Three 6 Dots face up, one of them a joker")
            Text("Three 6 Dots face up, one of them a joker. Jokers can stand in for any tile in a set of 3 or more.")
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
          }
          VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Why the Helper asks")
              .font(Typography.h2)
              .foregroundStyle(theme.text)
              .accessibilityAddTraits(.isHeader)
            Text("It tells the Helper which tiles you've already committed, and rules out concealed hands.")
              .font(Typography.body)
              .foregroundStyle(theme.text)
            Text("If you haven't called anything yet, leave your exposed sets empty.")
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
          }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(theme.bg)
      .navigationTitle("Exposed sets")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("exposureInfo.done")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .accessibilityIdentifier("exposureInfo.sheet")
  }
}
