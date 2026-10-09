import MahjongCore
import SwiftUI

/// The assist-gated "Closest hands" list (SPEC §11.3, §11.7).
struct ResultsSection: View {
  @Environment(\.theme) private var theme
  @Environment(HelperStore.self) private var helper

  let results: [LineResult]
  let pinnedLineID: String?
  let gate: HelperGate
  @Binding var revealed: Bool

  @State private var showAll = false
  @State private var expandedID: String?

  /// The pinned line first (with a pin), then the rest in engine order.
  private var ordered: [LineResult] {
    guard let pinnedLineID, let pinned = results.first(where: { $0.line.id == pinnedLineID }) else {
      return results
    }
    return [pinned] + results.filter { $0.line.id != pinnedLineID }
  }

  var body: some View {
    if gate.showsClosestHands(revealed: revealed) {
      list
    } else if gate.level == .peek {
      Button {
        withAnimation(.smooth(duration: 0.2)) { revealed = true }
      } label: {
        Label("Show closest hands", systemImage: "eye")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton(.secondary, size: .large))
      .accessibilityHint("Shows the hands you are closest to")
      .accessibilityIdentifier("helper.results.reveal")
    }
  }

  @ViewBuilder
  private var list: some View {
    let all = ordered
    let hasPinned = pinnedLineID.map { id in all.first?.line.id == id } ?? false
    // The pinned line does not count towards the limit.
    let limit = gate.visibleHandCount(total: all.count - (hasPinned ? 1 : 0), showAll: showAll) + (hasPinned ? 1 : 0)
    let shown = Array(all.prefix(limit))
    let ids = shown.map(\.line.id)
    VStack(alignment: .leading, spacing: Spacing.sm) {
      HStack {
        Text("Closest hands")
          .font(Typography.h2)
          .foregroundStyle(theme.text)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: Spacing.sm)
        if gate.level == .peek {
          Button("Hide") {
            withAnimation(.smooth(duration: 0.2)) { revealed = false }
          }
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.primary)
          .frame(minHeight: 44)
          .accessibilityIdentifier("helper.results.hide")
        }
      }
      if all.isEmpty {
        Text("This card has no hands to compare yet.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
      VStack(spacing: Spacing.sm) {
        ForEach(Array(shown.enumerated()), id: \.element.line.id) { entry in
          ResultCardView(
            result: entry.element, index: entry.offset,
            isPinned: hasPinned && entry.offset == 0,
            isExpanded: gate.canExpandHands && expandedID == entry.element.line.id,
            showsMissingInline: gate.showsMissingInline
          ) {
            withAnimation(.smooth(duration: 0.2)) {
              expandedID = expandedID == entry.element.line.id ? nil : entry.element.line.id
            }
          }
        }
      }
      .animation(.smooth(duration: 0.2), value: ids)
      if hasPinned {
        Button("Unpin this hand") {
          withAnimation(.smooth(duration: 0.2)) { helper.pin(lineID: nil) }
        }
        .buttonStyle(PrimaryButton(.ghost))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("helper.results.unpin")
      }
      if gate.offersShowAll(total: all.count - (hasPinned ? 1 : 0)) {
        Button(showAll ? "Show fewer" : "Show all \(all.count) hands") {
          withAnimation(.smooth(duration: 0.2)) { showAll.toggle() }
        }
        .buttonStyle(PrimaryButton(.ghost))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("helper.results.showall")
      }
    }
  }
}
