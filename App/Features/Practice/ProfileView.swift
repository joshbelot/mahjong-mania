import MahjongCore
import SwiftUI

/// The player's profile (SPEC §18.6): level, streaks, a 12-week calendar, accuracy by skill and badges.
struct ProfileView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(PracticeStore.self) private var practice

  private var progress: PracticeProgress { practice.progress }
  private var level: Levels.Position { progress.level }
  private var streak: StreakState { StreakLogic.display(progress.streak, today: practice.today) }

  var body: some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        levelCard
        streakCard
        calendarCard
        accuracyCard
        badgesCard
      }
    }
    .navigationTitle("Profile")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Level

  private var levelCard: some View {
    SectionCard {
      HStack(spacing: Spacing.lg) {
        ZStack {
          Circle().fill(theme.primary)
          Text("\(level.level)")
            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(theme.onPrimary)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Spacing.xs) {
          Text(level.title)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .accessibilityIdentifier("profile.title")
          ProgressBar(fraction: Double(level.into) / Double(max(1, level.needed)))
          Text("\(level.needed - level.into) XP to level \(level.level + 1)")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
          Text("\(progress.xp) XP in all")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .accessibilityIdentifier("profile.xp")
        }
      }
      .accessibilityElement(children: .combine)
    }
  }

  // MARK: Streak

  private var streakCard: some View {
    SectionCard("Streak") {
      AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.lg) {
        stat("flame.fill", theme.accent, "\(streak.current)", "Current", id: "profile.streak.current")
        stat("trophy.fill", theme.gold, "\(max(streak.longest, progress.streak.longest))", "Longest", id: "profile.streak.longest")
        stat("snowflake", theme.primary, "\(streak.freezes)", streak.freezes == 1 ? "Freeze" : "Freezes", id: "profile.freezes")
      }
      Text(streakNote)
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Text("Daily goal")
          .font(Typography.body)
          .foregroundStyle(theme.text)
        Spacer()
        Text("\(progress.dailyGoal.title): \(progress.dailyGoal.lessons == 1 ? "1 lesson" : "\(progress.dailyGoal.lessons) lessons")")
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.primary)
          .accessibilityIdentifier("profile.goal")
      }
    }
  }

  private var streakNote: String {
    if streak.current == 0 { return "Finish a lesson to start a streak. A streak freeze (earned every 7 days) covers a day you miss." }
    if progress.goalMet(on: practice.today) { return "Today's goal is done. Come back tomorrow to keep your \(streak.current)-day streak." }
    return "Reach today's goal to keep your streak growing."
  }

  private func stat(_ symbol: String, _ tint: Color, _ value: String, _ label: String, id: String) -> some View {
    HStack(spacing: Spacing.sm) {
      Image(systemName: symbol).font(.title3).foregroundStyle(tint).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 0) {
        Text(value).font(Typography.h2.monospacedDigit()).foregroundStyle(theme.text)
        Text(label).tinyStyle().foregroundStyle(theme.textMuted)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
    .accessibilityIdentifier(id)
  }

  // MARK: Calendar

  private static let weeks = 12

  private var calendarCard: some View {
    let today = practice.today
    let weekStart = today.adding(days: -(today.isoWeekday - 1))
    let start = weekStart.adding(days: -7 * (Self.weeks - 1))
    let played = (0..<(Self.weeks * 7)).filter { progress.lessonsPlayed(on: start.adding(days: $0)) > 0 }.count
    return SectionCard("Last 12 weeks") {
      HStack(alignment: .top, spacing: 4) {
        ForEach(0..<Self.weeks, id: \.self) { week in
          VStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { weekday in
              let day = start.adding(days: week * 7 + weekday)
              RoundedRectangle(cornerRadius: 3)
                .fill(color(for: day, today: today))
                .aspectRatio(1, contentMode: .fit)
            }
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Calendar of the last 12 weeks")
      .accessibilityValue("You practised on \(played) days")
      .accessibilityIdentifier("profile.calendar")
      Text("Practised on \(played) of the last \(Self.weeks * 7) days.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
    }
  }

  private func color(for day: LocalDay, today: LocalDay) -> Color {
    if day > today { return .clear }
    switch progress.lessonsPlayed(on: day) {
    case 0: return theme.border.opacity(0.6)
    case 1: return theme.primary.opacity(0.4)
    case 2, 3: return theme.primary.opacity(0.7)
    default: return theme.primary
    }
  }

  // MARK: Accuracy

  private var accuracyCard: some View {
    SectionCard("Accuracy by skill") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(Curriculum.Skill.allCases, id: \.self) { skill in
          let accuracy = progress.counters.accuracy(skill)
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              Text(skill.title).font(Typography.small.weight(.semibold)).foregroundStyle(theme.text)
              Spacer()
              Text(accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "Not yet")
                .font(Typography.small.monospacedDigit())
                .foregroundStyle(theme.textMuted)
            }
            ProgressBar(fraction: accuracy ?? 0)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(skill.title)
          .accessibilityValue(accuracy.map { "\(Int(($0 * 100).rounded())) percent right first time" } ?? "Not practised yet")
          .accessibilityIdentifier("profile.skill.\(skill.rawValue)")
        }
      }
      Text("Right first time, without a hint.")
        .font(Typography.tiny)
        .foregroundStyle(theme.textFaint)
    }
  }

  // MARK: Badges

  private var badgesCard: some View {
    SectionCard("Badges (\(progress.badges.count) of \(BadgeID.allCases.count))") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 220 : 104), spacing: Spacing.md, alignment: .top)], spacing: Spacing.md) {
        ForEach(BadgeID.allCases, id: \.self) { badge in
          let earned = progress.badges[badge.rawValue] != nil
          VStack(spacing: Spacing.xs) {
            ZStack {
              Circle().fill(earned ? theme.gold : theme.surfaceAlt)
              Image(systemName: earned ? badge.symbol : "lock.fill")
                .font(.title2)
                .foregroundStyle(earned ? theme.onPrimary : theme.textFaint)
            }
            .frame(width: 56, height: 56)
            Text(badge.title)
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(earned ? theme.text : theme.textMuted)
              .multilineTextAlignment(.center)
            Text(badge.goal)
              .font(Typography.tiny)
              .foregroundStyle(theme.textFaint)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(badge.title). \(badge.goal)")
          .accessibilityValue(earned ? "Earned" : "Locked")
          .accessibilityIdentifier("profile.badge.\(badge.rawValue)")
        }
      }
    }
  }
}
