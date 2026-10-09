import MahjongCore
import SwiftUI

/// Scout mode: what the other players have exposed, which hands they could be going for, and which
/// tiles are risky to throw (SPEC §10.6, §11.7).
struct ScoutView: View {
  @Environment(\.theme) private var theme
  @Environment(HelperStore.self) private var helper

  let analyzer: Analyzer
  let gate: HelperGate
  let advisor: HelperAdvisor
  let onAddExposure: (Int) -> Void

  @State private var showAllDanger = false

  private static let linesShown = 5
  private static let dangerShown = 10

  private var hasExposures: Bool { helper.opponents.contains { !$0.exposures.isEmpty } }

  var body: some View {
    let report = advisor.scout(analyzer, opponents: helper.opponents, seen: helper.seen)
    VStack(alignment: .leading, spacing: Spacing.lg) {
      ForEach(Array(helper.opponents.enumerated()), id: \.offset) { entry in
        opponentCard(entry.element, index: entry.offset, report: report)
      }
      if hasExposures {
        if gate.showsDanger { dangerSection(report) }
        if gate.showsDanger { saferSection(report) }
        Button("Clear opponents") {
          withAnimation(.smooth(duration: 0.2)) { helper.clearOpponents() }
        }
        .buttonStyle(PrimaryButton(.ghost))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("scout.clear")
      } else {
        emptyState
      }
    }
  }

  // MARK: Opponents

  private func opponentCard(_ opponent: OpponentInput, index: Int, report: ScoutReport) -> some View {
    SectionCard {
      Text(opponent.label)
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      ExposuresRow(
        exposures: opponent.exposures, identifierPrefix: "scout.\(index)",
        onRemove: { helper.removeOpponentExposure(at: $0, opponentIndex: index) },
        onAdd: { onAddExposure(index) })
      if !opponent.exposures.isEmpty {
        couldBeGoingFor(opponent, report: report)
      }
    }
  }

  @ViewBuilder
  private func couldBeGoingFor(_ opponent: OpponentInput, report: ScoutReport) -> some View {
    let lines = report.perOpponent.first { $0.label == opponent.label }?.lines ?? []
    VStack(alignment: .leading, spacing: Spacing.sm) {
      if lines.isEmpty {
        Text("Nothing on this card fits what they've shown.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else {
        Text("Could be going for:")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.textMuted)
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
          ForEach(Array(lines.prefix(Self.linesShown)), id: \.id) { line in
            Text(line.displayName)
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.text)
              .padding(.horizontal, Spacing.md)
              .padding(.vertical, Spacing.xs)
              .background(theme.surfaceAlt, in: Capsule())
          }
          if lines.count > Self.linesShown {
            Text("+\(lines.count - Self.linesShown) more")
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
              .padding(.vertical, Spacing.xs)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("scout.lines.\(opponent.label)")
  }

  private var emptyState: some View {
    VStack(spacing: Spacing.sm) {
      Image(systemName: "binoculars")
        .font(.largeTitle)
        .foregroundStyle(theme.textFaint)
        .accessibilityHidden(true)
      Text("Add what they've exposed to see what they might be going for.")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(Spacing.lg)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("scout.empty")
  }

  // MARK: Danger and safer tiles

  private func dangerSection(_ report: ScoutReport) -> some View {
    let ranked = report.danger.filter { $0.value > 0 }.map { DangerEntry(tile: $0.key, value: $0.value) }
      .sorted { a, b in a.value != b.value ? a.value > b.value : a.tile < b.tile }
    let shown = showAllDanger ? ranked : Array(ranked.prefix(Self.dangerShown))
    let reasons = gate.showsDangerReasons ? dangerReasons(report) : [:]
    return SectionCard {
      Text("Danger tiles")
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      if ranked.isEmpty {
        Text("Nothing here is risky to throw right now.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      } else {
        Text("Think twice before throwing these.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        VStack(spacing: Spacing.sm) {
          ForEach(Array(shown.enumerated()), id: \.element.id) { entry in
            dangerRow(
              tile: entry.element.tile, value: entry.element.value, reason: reasons[entry.element.tile],
              index: entry.offset)
          }
        }
        if ranked.count > Self.dangerShown {
          Button(showAllDanger ? "Show fewer" : "Show all \(ranked.count) tiles") {
            withAnimation(.smooth(duration: 0.2)) { showAllDanger.toggle() }
          }
          .buttonStyle(PrimaryButton(.ghost))
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("scout.danger.showall")
        }
      }
    }
  }

  private func dangerLevel(_ value: Double) -> String {
    if value >= 0.66 { return "High" }
    if value >= 0.33 { return "Medium" }
    return "Low"
  }

  private func dangerRow(tile: Tile, value: Double, reason: String?, index: Int) -> some View {
    HStack(alignment: .center, spacing: Spacing.md) {
      TileView(tile: tile, size: .small)
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(spacing: Spacing.sm) {
          HeatBar(value: value)
          Text(dangerLevel(value))
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.textMuted)
            .frame(minWidth: 56, alignment: .trailing)
        }
        if let reason {
          Text(reason)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
        }
      }
    }
    .frame(minHeight: 44)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(tile.name), \(dangerLevel(value)) danger" + (reason.map { ". \($0)" } ?? ""))
    .accessibilityIdentifier("danger.row.\(index)")
  }

  private func saferSection(_ report: ScoutReport) -> some View {
    let safe = report.safe.filter { $0 != .flower }
    return SectionCard {
      Text("Safer tiles")
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      Text("Nothing they've shown needs these.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
      FlowLayout(spacing: 4, lineSpacing: 4) {
        ForEach(safe, id: \.self) { tile in
          TileView(tile: tile, size: .small)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// A short "why" per risky tile: which opponents' possible hands use it (Coach).
  private func dangerReasons(_ report: ScoutReport) -> [Tile: String] {
    var usedBy: [Tile: [String: Set<String>]] = [:]
    var labelsByLine: [String: [String]] = [:]
    for read in report.perOpponent {
      for line in read.lines { labelsByLine[line.id, default: []].append(read.label) }
    }
    for target in analyzer.targets {
      guard let labels = labelsByLine[target.lineID] else { continue }
      for group in target.groups where report.danger[group.tile] != nil {
        for label in labels { usedBy[group.tile, default: [:]][label, default: []].insert(target.lineID) }
      }
    }
    var reasons: [Tile: String] = [:]
    for (tile, byLabel) in usedBy {
      let parts = byLabel.sorted { a, b in
        a.value.count != b.value.count ? a.value.count > b.value.count : a.key < b.key
      }.map { "\($0.value.count) of \($0.key)'s" }
      guard !parts.isEmpty else { continue }
      let joined: String
      if parts.count == 1 {
        joined = parts[0]
      } else {
        joined = parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "")
      }
      reasons[tile] = "Fits \(joined) possible hands."
    }
    return reasons
  }
}

private struct DangerEntry: Identifiable {
  let tile: Tile
  let value: Double
  var id: Tile { tile }
}

/// A bar that fills from amber towards red as `value` (0...1) grows.
private struct HeatBar: View {
  @Environment(\.theme) private var theme
  let value: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.surfaceAlt)
        Capsule()
          .fill(LinearGradient(colors: [theme.warning, theme.danger], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(10, proxy.size.width * min(1, max(0, value))))
      }
    }
    .frame(height: 10)
    .accessibilityHidden(true)
  }
}
