import MahjongCore
import SwiftUI

/// The vertical path of units and nodes (SPEC §18.4).
struct PathView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let nodes: [PathNode]
  let progress: PracticeProgress
  var reviewDue = 0
  let onTap: (PathNode) -> Void
  let onTestOut: (Int) -> Void
  /// The node that just unlocked, which pops once per `popTick`.
  var popNodeID: String?
  var popTick = 0

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xl) {
      ForEach(Curriculum.units) { unit in
        unitSection(unit)
      }
    }
  }

  private func unitSection(_ unit: UnitSpec) -> some View {
    let unitNodes = nodes.filter { $0.spec.unit == unit.id }
    let done = unitNodes.filter { $0.status == .done || $0.status == .testedOut }.count
    return VStack(alignment: .leading, spacing: Spacing.lg) {
      UnitHeader(
        unit: unit, done: done, total: unitNodes.count,
        finished: progress.isUnitFinished(unit.id), gold: progress.units[unit.id]?.gold == true,
        canTestOut: progress.canTestOut(unit.id), onTestOut: { onTestOut(unit.id) })
      VStack(spacing: Spacing.lg) {
        ForEach(Array(unitNodes.enumerated()), id: \.element.id) { entry in
          NodeButton(
            node: entry.element, offset: offset(entry.offset), popTick: entry.element.id == popNodeID ? popTick : 0,
            badge: entry.element.spec.kind == .review && reviewDue > 0 ? reviewDue : nil
          ) { onTap(entry.element) }
            .id("node.\(entry.element.id)")
        }
      }
      .frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("path.unit.\(unit.id)")
  }

  /// A gentle zig-zag; straight at accessibility sizes where there is no room to sway.
  private func offset(_ index: Int) -> CGFloat {
    if typeSize.isAccessibilitySize { return 0 }
    let pattern: [CGFloat] = [0, 40, 64, 40, 0, -40, -64, -40]
    return pattern[index % pattern.count]
  }
}

struct UnitHeader: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let unit: UnitSpec
  let done: Int
  let total: Int
  let finished: Bool
  let gold: Bool
  let canTestOut: Bool
  let onTestOut: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      AdaptiveStack(horizontalAlignment: .leading, verticalAlignment: .top, spacing: Spacing.md) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Unit \(unit.id)\(gold ? " · Gold" : finished ? " · Done" : "")")
            .tinyStyle()
            .foregroundStyle(gold ? theme.gold : theme.textMuted)
          Text(unit.title)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .accessibilityAddTraits(.isHeader)
          Text(unit.summary)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: Spacing.sm)
        if !typeSize.isAccessibilitySize { UnitArt(unit: unit.id, size: .small) }
        if canTestOut {
          Button("Test out", action: onTestOut)
            .buttonStyle(PrimaryButton(.ghost))
            .accessibilityHint("Skip this unit by getting 8 of 10 right")
            .accessibilityIdentifier("path.testout.\(unit.id)")
        }
      }
      ProgressBar(fraction: Double(done) / Double(max(1, total)))
        .accessibilityHidden(true)
    }
    .padding(Spacing.lg)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(gold ? theme.gold : theme.border, lineWidth: gold ? 2 : 1))
  }
}

/// One circular node of the path.
struct NodeButton: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let node: PathNode
  let offset: CGFloat
  var popTick = 0
  /// A number shown on the node (questions waiting in a review node).
  var badge: Int?
  let action: () -> Void
  @State private var pulse = false

  private var isNext: Bool { node.status == .next }

  var body: some View {
    Button(action: action) {
      VStack(spacing: Spacing.xs) {
        if isNext {
          Text("Start")
            .font(Typography.small.weight(.bold))
            .foregroundStyle(theme.primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 4)
            .background(theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.primary, lineWidth: 1.5))
            .accessibilityHidden(true)
        }
        ZStack {
          Circle().fill(fill)
          Circle().strokeBorder(ring, lineWidth: isNext ? 4 : 2)
          Image(systemName: symbol)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(symbolColor)
        }
        .frame(width: 68, height: 68)
        .overlay(alignment: .topTrailing) {
          if let badge {
            Text("\(badge)")
              .font(Typography.tiny.monospacedDigit())
              .foregroundStyle(theme.onPrimary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(theme.accent, in: Capsule())
              .accessibilityHidden(true)
          }
        }
        .scaleEffect(isNext && pulse && !reduceMotion ? 1.05 : 1)
        .pop(trigger: popTick, enabled: popTick > 0)
        if node.status == .done && node.spec.kind == .lesson {
          StarsView(count: node.stars, size: 14)
        }
        Text(node.spec.title)
          .font(Typography.small.weight(.medium))
          .foregroundStyle(node.status == .locked ? theme.textFaint : theme.text)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .frame(maxWidth: 180)
      }
      .frame(minWidth: 88, minHeight: 88)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .offset(x: offset)
    .onAppear {
      guard isNext else { return }
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("path.node.\(node.spec.id)")
  }

  private var fill: Color {
    switch node.status {
    case .next: return theme.primary
    case .done: return node.gold ? theme.gold : theme.primarySoft
    case .testedOut: return theme.surfaceAlt
    case .locked: return theme.surfaceAlt
    }
  }

  private var ring: Color {
    switch node.status {
    case .next: return theme.primary.opacity(0.35)
    case .done: return node.gold ? theme.gold : theme.primary
    case .testedOut: return theme.primary.opacity(0.5)
    case .locked: return theme.border
    }
  }

  private var symbol: String {
    if node.status == .locked { return "lock.fill" }
    switch node.spec.kind {
    case .lesson: return node.status == .done ? "star.fill" : "play.fill"
    case .review: return "dumbbell.fill"
    case .checkpoint: return "flag.checkered"
    }
  }

  private var symbolColor: Color {
    switch node.status {
    case .next: return theme.onPrimary
    case .done: return node.gold ? theme.onPrimary : theme.primary
    case .testedOut: return theme.primary
    case .locked: return theme.textFaint
    }
  }

  private var label: String {
    let kind: String
    switch node.spec.kind {
    case .lesson: kind = "Lesson"
    case .review: kind = "Review"
    case .checkpoint: kind = "Checkpoint"
    }
    return "\(kind): \(node.spec.title)"
  }

  private var value: String {
    switch node.status {
    case .next: return badge.map { "Next, \($0) to review" } ?? "Next"
    case .locked: return "Locked"
    case .testedOut: return "Tested out"
    case .done:
      if node.spec.kind == .lesson { return "\(node.stars) of 3 stars\(node.gold ? ", gold" : "")" }
      return "Done"
    }
  }
}

/// What a tap on a played or locked node shows.
struct NodeDetailSheet: View {
  @Environment(\.theme) private var theme
  let node: PathNode
  let progress: PracticeProgress
  /// `true` = play it as a gold lesson.
  let onPlay: (Bool) -> Void

  private var goldAvailable: Bool {
    node.spec.kind == .lesson && node.status == .done && node.stars == 3
      && (progress.goldAvailable(node.spec.unit) || progress.units[node.spec.unit]?.gold == true)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.lg) {
      Text(node.spec.title)
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      switch node.status {
      case .locked:
        Text("Finish the nodes before this one to unlock it. Or use Test out on the unit if you already know this.")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      case .done, .testedOut:
        if node.spec.kind == .lesson {
          StarsView(count: node.stars, size: 32)
          if node.status == .testedOut {
            Text("You tested out of this one, so it has no stars yet.")
              .font(Typography.body)
              .foregroundStyle(theme.textMuted)
          }
        }
        Button(node.status == .testedOut ? "Play" : "Play again") { onPlay(false) }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("node.play")
        if goldAvailable {
          Button("Go gold") { onPlay(true) }
            .buttonStyle(PrimaryButton(.secondary, size: .large))
            .accessibilityHint("The same lesson, a level harder, with no hints")
            .accessibilityIdentifier("node.gold")
        }
      case .next:
        EmptyView()
      }
      Spacer(minLength: 0)
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.bg.ignoresSafeArea())
  }
}
