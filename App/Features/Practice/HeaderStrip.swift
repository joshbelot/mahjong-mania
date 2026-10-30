import MahjongCore
import SwiftUI

/// Level badge with an XP bar, the streak flame, and today's goal ring (SPEC §18.2).
struct HeaderStrip: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(PracticeStore.self) private var practice

  private var progress: PracticeProgress { practice.progress }
  private var level: Levels.Position { progress.level }
  private var streak: StreakState { StreakLogic.display(progress.streak, today: practice.today) }
  private var lessonsToday: Int { progress.lessonsPlayed(on: practice.today) }

  var body: some View {
    AdaptiveStack(spacing: Spacing.lg) {
      NavigationLink(value: PracticeRoute.profile) { levelBlock }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your profile")
      if typeSize.isAccessibilitySize == false { Spacer(minLength: 0) }
      HStack(spacing: Spacing.lg) {
        NavigationLink(value: PracticeRoute.profile) { streakBlock }
          .buttonStyle(.plain)
        goalBlock
        TilesButton()
      }
    }
  }

  private var levelBlock: some View {
    HStack(spacing: Spacing.sm) {
      ZStack {
        Circle().fill(theme.primary)
        Text("\(level.level)")
          .font(Typography.h2.monospacedDigit())
          .foregroundStyle(theme.onPrimary)
      }
      .frame(width: 40, height: 40)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(level.title)
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.text)
          .lineLimit(1)
        ProgressBar(fraction: Double(level.into) / Double(max(1, level.needed)))
          .frame(width: 96)
        Text("\(level.into)/\(level.needed) XP")
          .font(Typography.tiny)
          .foregroundStyle(theme.textMuted)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Level \(level.level), \(level.title)")
    .accessibilityValue("\(level.into) of \(level.needed) XP")
    .accessibilityIdentifier("header.level")
  }

  private var streakBlock: some View {
    let active = streak.current > 0
    return HStack(spacing: 4) {
      Image(systemName: "flame.fill")
        .foregroundStyle(active ? theme.accent : theme.textFaint)
      Text("\(streak.current)")
        .font(Typography.h2.monospacedDigit())
        .foregroundStyle(active ? theme.text : theme.textMuted)
      if streak.freezes > 0 {
        Image(systemName: "snowflake")
          .font(.footnote)
          .foregroundStyle(theme.primary)
        Text("\(streak.freezes)")
          .font(Typography.small.monospacedDigit())
          .foregroundStyle(theme.primary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Streak")
    .accessibilityValue(
      (streak.current == 1 ? "1 day" : "\(streak.current) days")
        + (streak.freezes > 0 ? ", \(streak.freezes) \(streak.freezes == 1 ? "freeze" : "freezes") held" : ""))
    .accessibilityIdentifier("header.streak")
  }

  private var goalBlock: some View {
    let goal = progress.dailyGoal.lessons
    let met = progress.goalMet(on: practice.today)
    let fraction = met ? 1 : min(1, Double(lessonsToday) / Double(max(1, goal)))
    return ZStack {
      Circle().stroke(theme.border, lineWidth: 5)
      Circle()
        .trim(from: 0, to: fraction)
        .stroke(fraction >= 1 ? theme.success : theme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .rotationEffect(.degrees(-90))
      if fraction >= 1 {
        Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(theme.success)
      } else {
        Text("\(lessonsToday)/\(goal)").font(Typography.tiny.monospacedDigit()).foregroundStyle(theme.textMuted)
      }
    }
    .frame(width: 40, height: 40)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Today's goal")
    .accessibilityValue(met ? "Done for today" : "\(lessonsToday) of \(goal) lessons")
    .accessibilityIdentifier("header.goal")
  }
}
