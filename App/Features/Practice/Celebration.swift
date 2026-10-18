import MahjongCore
import SwiftUI

/// A full-screen moment after a play: a new level, a badge (SPEC §18.6–§18.7). Streak and goal screens
/// join the same queue in Phase 25.
enum CelebrationItem: Hashable, Identifiable {
  case levelUp(level: Int, title: String)
  case badge(BadgeID)
  case goalMet(streak: Int)
  case milestone(days: Int)
  case freezeEarned(held: Int)
  case freezeUsed(streak: Int)
  case streakBroken(daysPlayed: Int)

  var id: String {
    switch self {
    case .levelUp(let level, _): return "level.\(level)"
    case .badge(let badge): return "badge.\(badge.rawValue)"
    case .goalMet: return "goal"
    case .milestone(let days): return "milestone.\(days)"
    case .freezeEarned: return "freeze.earned"
    case .freezeUsed: return "freeze.used"
    case .streakBroken: return "streak.broken"
    }
  }
}

enum Celebrations {
  /// What to celebrate after `outcome`, in the order to show it.
  static func items(for outcome: PlayOutcome) -> [CelebrationItem] {
    var items: [CelebrationItem] = []
    if let level = outcome.levelUp { items.append(.levelUp(level: level.level, title: level.title)) }
    items += outcome.newBadges.map { .badge($0) }
    var streakNow = 0
    for event in outcome.streakEvents {
      switch event {
      case .streakGrew(let days): streakNow = days
      default: break
      }
    }
    for event in outcome.streakEvents {
      if case .milestone(let days) = event { items.append(.milestone(days: days)) }
    }
    for event in outcome.streakEvents {
      if case .freezeEarned(let held) = event { items.append(.freezeEarned(held: held)) }
    }
    if outcome.goalJustMet && !items.contains(where: { if case .milestone = $0 { return true } else { return false } }) {
      items.append(.goalMet(streak: streakNow))
    }
    return items
  }
}

/// Confetti of tiles and flowers falling for about 1.5 seconds, drawn in a Canvas. Draws nothing with
/// Reduce Motion on.
struct ConfettiView: View {
  @Environment(\.reduceMotion) private var reduceMotion
  @Environment(\.theme) private var theme
  @State private var start = Date()

  private struct Piece {
    var x: Double
    var delay: Double
    var speed: Double
    var spin: Double
    var size: Double
    var kind: Int
    var color: Int
  }

  private let pieces: [Piece] = {
    var rng = SeededRandom(seed: 0xC0FFEE)
    func unit() -> Double { Double(rng.next() % 10_000) / 10_000 }
    return (0..<46).map { _ in
      Piece(
        x: unit(), delay: unit() * 0.45, speed: 0.75 + unit() * 0.5, spin: (unit() - 0.5) * 9,
        size: 12 + unit() * 10, kind: Int(rng.next() % 3), color: Int(rng.next() % 4))
    }
  }()

  var body: some View {
    if !reduceMotion {
      TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
        let t = timeline.date.timeIntervalSince(start)
        Canvas { context, size in
          guard t < 2.2 else { return }
          let palette = [theme.accent, theme.gold, theme.primary, theme.flower]
          for piece in pieces {
            let local = t - piece.delay
            guard local > 0 else { continue }
            let y = -30 + local * piece.speed * size.height * 0.62
            guard y < size.height + 30 else { continue }
            let x = piece.x * size.width + sin(local * 3 + piece.spin) * 14
            var layer = context
            layer.translateBy(x: x, y: y)
            layer.rotate(by: .radians(local * piece.spin))
            layer.opacity = max(0, min(1, (1.9 - t) * 2))
            draw(piece, in: &layer, color: palette[piece.color])
          }
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear { start = Date() }
    }
  }

  private func draw(_ piece: Piece, in context: inout GraphicsContext, color: Color) {
    let s = piece.size
    switch piece.kind {
    case 0:  // a tile: ivory face with a coloured back edge
      let tile = CGRect(x: -s * 0.35, y: -s * 0.5, width: s * 0.7, height: s)
      context.fill(Path(roundedRect: tile.offsetBy(dx: 0, dy: 2), cornerRadius: 3), with: .color(color))
      context.fill(Path(roundedRect: tile, cornerRadius: 3), with: .color(theme.tileFace))
      context.stroke(Path(roundedRect: tile, cornerRadius: 3), with: .color(color.opacity(0.5)), lineWidth: 0.5)
      context.fill(Path(ellipseIn: CGRect(x: -s * 0.13, y: -s * 0.13, width: s * 0.26, height: s * 0.26)), with: .color(color))
    case 1:  // a flower: five petals round a centre
      for i in 0..<5 {
        let angle = Double(i) * 2 * .pi / 5
        let petal = CGRect(x: cos(angle) * s * 0.28 - s * 0.17, y: sin(angle) * s * 0.28 - s * 0.17, width: s * 0.34, height: s * 0.34)
        context.fill(Path(ellipseIn: petal), with: .color(color))
      }
      context.fill(Path(ellipseIn: CGRect(x: -s * 0.1, y: -s * 0.1, width: s * 0.2, height: s * 0.2)), with: .color(theme.tileFace))
    default:  // a small ribbon
      context.fill(Path(roundedRect: CGRect(x: -s * 0.4, y: -s * 0.12, width: s * 0.8, height: s * 0.24), cornerRadius: 2), with: .color(color))
    }
  }
}

/// One celebration moment, full screen, with a Continue button.
struct CelebrationView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let item: CelebrationItem
  let isLast: Bool
  let onContinue: () -> Void
  @State private var revealed = false
  @State private var cue = 0

  private var content: (symbol: String, tint: Color, title: String, subtitle: String, extra: String?) {
    switch item {
    case .levelUp(let level, let title):
      return ("arrow.up.circle.fill", theme.primary, "Level \(level)", title, "Keep going: every lesson earns XP.")
    case .badge(let badge):
      return (badge.symbol, theme.gold, badge.title, "New badge", badge.goal + ". +\(XP.badge) XP")
    case .goalMet(let streak):
      return (
        "checkmark.seal.fill", theme.success, "Daily goal met",
        streak > 0 ? "\(streak)-day streak" : "Nice work today", "Come back tomorrow to keep it growing."
      )
    case .milestone(let days):
      return ("flame.fill", theme.accent, "\(days)-day streak!", "A streak milestone", "That's \(days) days of practice in a row.")
    case .freezeEarned(let held):
      return (
        "snowflake", theme.primary, "Streak freeze earned",
        "You hold \(held) \(held == 1 ? "freeze" : "freezes")", "A freeze covers a missed day so your streak stays safe."
      )
    case .freezeUsed(let streak):
      return ("snowflake", theme.primary, "Streak saved", StreakLogic.freezeMessage(streak: streak), nil)
    case .streakBroken(let days):
      return ("sun.max.fill", theme.gold, "Welcome back", StreakLogic.brokenMessage(daysPlayed: days), "Every lesson counts. Start a new streak today.")
    }
  }

  var body: some View {
    let c = content
    ZStack {
      theme.bg.ignoresSafeArea()
      if celebratesWithConfetti { ConfettiView().ignoresSafeArea() }
      VStack(spacing: Spacing.xl) {
        Spacer(minLength: Spacing.xl)
        ZStack {
          Circle().fill(c.tint.opacity(0.18)).frame(width: 190, height: 190)
          Circle().fill(c.tint).frame(width: 140, height: 140)
          Image(systemName: c.symbol)
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(theme.onPrimary)
        }
        .scaleEffect(revealed || reduceMotion ? 1 : 0.4)
        .opacity(revealed || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
        VStack(spacing: Spacing.sm) {
          Text(c.title)
            .titleStyle()
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("celebration.title")
          Text(c.subtitle)
            .font(Typography.h2)
            .foregroundStyle(c.tint)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("celebration.subtitle")
          if let extra = c.extra {
            Text(extra)
              .font(Typography.body)
              .foregroundStyle(theme.textMuted)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.horizontal, Spacing.lg)
        Spacer(minLength: Spacing.xl)
        Button(isLast ? "Continue" : "Next", action: onContinue)
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .padding(.horizontal, Spacing.lg)
          .padding(.bottom, Spacing.lg)
          .accessibilityIdentifier("celebration.continue")
      }
      .frame(maxWidth: 640)
    }
    .onAppear {
      withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.6)) { revealed = true }
      cue += 1
    }
    .sound(trigger: cue) { _ in .fanfare }
    .hapticOnChange(trigger: cue) { _ in .success }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("celebration.\(item.id)")
  }

  private var celebratesWithConfetti: Bool {
    switch item {
    case .freezeUsed, .streakBroken: return false
    default: return true
    }
  }
}
