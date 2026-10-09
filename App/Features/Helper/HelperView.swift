import MahjongCore
import SwiftUI

private enum HelperSheet: Hashable, Identifiable {
  case card
  case call
  case exposure
  case opponent(Int)

  var id: Self { self }
}

/// The Helper tab (SPEC §4.2, §11.7): enter your tiles, see the hands you are closest to, and get
/// suggestions, all gated by the assist level (§11.3).
struct HelperView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(CardsStore.self) private var cards
  @Environment(HelperStore.self) private var helper

  @State private var advisor = HelperAdvisor()
  @State private var sheet: HelperSheet?
  @State private var keyboardCollapsed = false
  @State private var closestRevealed = false
  @State private var suggestionRevealed = false

  private var gate: HelperGate { HelperGate(settings.settings.assistLevel) }

  private var analyzer: Analyzer? {
    cards.analyzer(for: settings.settings.activeCardID) ?? cards.analyzer(for: PracticeCard.card.id)
  }

  private var exposedTileCount: Int {
    helper.exposures.reduce(0) { $0 + $1.tiles.count }
  }

  private var modeBinding: Binding<HelperMode> {
    let helper = helper
    return Binding(
      get: { MainActor.assumeIsolated { helper.mode } },
      set: { newValue in MainActor.assumeIsolated { helper.setMode(newValue) } })
  }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        CoachTipBanner(screen: "helper")
        HelperHeader(cardName: analyzer?.card.name ?? "Practice Card") { sheet = .card }
        SegmentedPicker("Mode", selection: modeBinding, options: HelperMode.allCases) { $0.title }
          .accessibilityIdentifier("helper.mode")
        if let analyzer {
          content(analyzer)
        } else {
          Text("This card could not be loaded.")
            .font(Typography.body)
            .foregroundStyle(theme.textMuted)
        }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { dock }
    .navigationTitle("Helper")
    .navigationBarTitleDisplayMode(.inline)
    .settingsToolbar()
    .sheet(item: $sheet) { sheet in
      sheetContent(sheet)
    }
    .onChange(of: helper.mode) {
      closestRevealed = false
      suggestionRevealed = false
    }
    .onChange(of: settings.settings.assistLevel) {
      closestRevealed = false
      suggestionRevealed = false
    }
    .onChange(of: helper.rack.count) { old, new in
      let full = HelperRules.fullRackCount(mode: helper.mode, exposedTiles: exposedTileCount)
      if new > old && new >= full {
        withAnimation(.smooth(duration: 0.2)) { keyboardCollapsed = true }
      }
    }
  }

  // MARK: Content

  @ViewBuilder
  private func content(_ analyzer: Analyzer) -> some View {
    if helper.mode == .scout {
      ScoutView(analyzer: analyzer, gate: gate, advisor: advisor) { sheet = .opponent($0) }
    } else {
      tilesContent(analyzer)
    }
  }

  @ViewBuilder
  private func tilesContent(_ analyzer: Analyzer) -> some View {
    let limit = HelperRules.rackLimit(mode: helper.mode, exposedTiles: exposedTileCount)
    TileRackView(
      tiles: settings.settings.tileSort == .suit ? helper.rack.sorted() : helper.rack,
      limit: limit,
      onRemove: remove,
      onClear: { helper.clearRack() })
    if helper.mode == .playing {
      exposuresCard
      SeenTilesSection()
    }
    if helper.rack.isEmpty && helper.exposures.isEmpty {
      emptyState
    } else {
      CoachPanel(
        mode: helper.mode, analyzer: analyzer, view: helper.view, seen: helper.seen,
        danger: playingDanger(analyzer), gate: gate, advisor: advisor,
        revealed: $suggestionRevealed, onCallCheck: { sheet = .call })
      ResultsSection(
        results: gate.showsClosestHands(revealed: closestRevealed)
          ? helper.results(using: analyzer) : [],
        pinnedLineID: helper.pinnedLineID, gate: gate, revealed: $closestRevealed)
    }
  }

  private func playingDanger(_ analyzer: Analyzer) -> [Tile: Double] {
    guard helper.mode == .playing, gate.showsDanger else { return [:] }
    return advisor.scout(analyzer, opponents: helper.opponents, seen: helper.seen).danger
  }

  private var exposuresCard: some View {
    SectionCard {
      Text("Exposures")
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      ExposuresRow(
        exposures: helper.exposures, identifierPrefix: "helper.exposures",
        onRemove: { helper.removeExposure(at: $0) }, onAdd: { sheet = .exposure })
    }
  }

  private var emptyState: some View {
    VStack(spacing: Spacing.md) {
      Image(systemName: "square.grid.3x2")
        .font(.largeTitle)
        .foregroundStyle(theme.textFaint)
        .accessibilityHidden(true)
      Text("Add your tiles to see which hands you're closest to.")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
        .multilineTextAlignment(.center)
      Button("Deal me a random hand", action: dealRandomHand)
        .buttonStyle(PrimaryButton(.ghost))
        .accessibilityIdentifier("helper.deal")
    }
    .frame(maxWidth: .infinity)
    .padding(Spacing.lg)
  }

  // MARK: Tile input

  @ViewBuilder
  private var dock: some View {
    if helper.mode != .scout && sheet == nil {
      let limit = HelperRules.rackLimit(mode: helper.mode, exposedTiles: exposedTileCount)
      let usage = helper.usage
      // The keyboard counts every tile in use; only the concealed rack is capped.
      let cap = limit + usage.values.reduce(0, +) - helper.rack.count
      VStack(spacing: 0) {
        Button {
          withAnimation(.smooth(duration: 0.2)) { keyboardCollapsed.toggle() }
        } label: {
          HStack(spacing: Spacing.xs) {
            Image(systemName: keyboardCollapsed ? "chevron.up" : "chevron.down")
              .font(Typography.small.weight(.semibold))
            Text(keyboardCollapsed ? "Show keyboard" : "Hide keyboard")
              .font(Typography.small.weight(.semibold))
          }
          .foregroundStyle(theme.textMuted)
          .frame(maxWidth: .infinity, minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(keyboardCollapsed ? "Show tile keyboard" : "Hide tile keyboard")
        .accessibilityIdentifier("helper.keyboard.toggle")
        if !keyboardCollapsed {
          TileKeyboardView(onAdd: add, usage: usage, limit: cap)
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .background(theme.surface)
      .overlay(alignment: .top) {
        Rectangle().fill(theme.border).frame(height: 1)
      }
    }
  }

  private func add(_ tile: Tile) {
    withAnimation(.snappy(duration: 0.12)) { helper.add(tile) }
  }

  private func remove(_ tile: Tile) {
    if let index = helper.rack.firstIndex(of: tile) { helper.removeTile(at: index) }
    withAnimation(.smooth(duration: 0.2)) { keyboardCollapsed = false }
  }

  private func dealRandomHand() {
    let dealt = Wall.deal(seed: UInt64.random(in: 1...UInt64.max), count: HelperRules.restingHandSize)
    withAnimation(.snappy(duration: 0.12)) { helper.setRack(dealt.hand) }
  }

  // MARK: Sheets

  /// Every copy accounted for anywhere: my tiles, my exposures, seen tiles and the opponents' exposures.
  private var knownUsage: TileCounts {
    var counts = helper.usage
    for opponent in helper.opponents {
      for exposure in opponent.exposures {
        for tile in exposure.tiles { counts[tile, default: 0] += 1 }
      }
    }
    return counts
  }

  @ViewBuilder
  private func sheetContent(_ sheet: HelperSheet) -> some View {
    switch sheet {
    case .card:
      CardPickerSheet()
    case .call:
      if let analyzer {
        CallCheckSheet(analyzer: analyzer, view: helper.view, usage: knownUsage, gate: gate)
      }
    case .exposure:
      ExposureSheet(title: "Add exposure", usage: knownUsage) { helper.addExposure($0) }
    case .opponent(let index):
      ExposureSheet(title: opponentTitle(index), usage: knownUsage) {
        helper.addOpponentExposure($0, at: index)
      }
    }
  }

  private func opponentTitle(_ index: Int) -> String {
    helper.opponents.indices.contains(index) ? "\(helper.opponents[index].label) exposed" : "Add exposure"
  }
}

@MainActor
private func helperPreview(_ scheme: ColorScheme, level: AssistLevel) -> some View {
  let stores = AppStores.inMemory()
  stores.settings.update { $0.assistLevel = level }
  stores.helper.setRack(
    ["1C", "2C", "3C", "5D", "5D", "6D", "6D", "6D", "N", "R", "0", "F", "J"].compactMap { Tile(code: $0) })
  return NavigationStack { HelperView() }
    .environment(stores.settings)
    .environment(stores.cards)
    .environment(stores.helper)
    .environment(TipCenter(seed: 1))
    .preferredColorScheme(scheme)
}

#Preview("Light") {
  helperPreview(.light, level: .coach)
}

#Preview("Dark") {
  helperPreview(.dark, level: .peek)
}
