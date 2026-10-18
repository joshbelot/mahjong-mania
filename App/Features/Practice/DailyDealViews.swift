import MahjongCore
import SwiftUI

/// What a Daily Deal play needs to turn its two answers into a result.
@MainActor
@Observable
final class DailyDealPlay {
  let day: LocalDay
  let pick: Exercise
  let pass: Exercise
  /// False for a replay (the day's scored attempt exists already).
  let scored: Bool
  private(set) var result: DailyDeal.Result?
  private(set) var shareText = ""

  init(day: LocalDay, analyzer: Analyzer, scored: Bool) {
    self.day = day
    let questions = DailyDeal.exercises(for: day, analyzer: analyzer)
    pick = questions.pick
    pass = questions.pass
    self.scored = scored
  }

  var number: Int { DailyDeal.number(for: day) }

  func session() -> LessonSession {
    LessonSession(title: "Daily Deal #\(number)", exercises: [pick, pass])
  }

  /// Turns the session's two answers into the result and records it when this is the scored attempt.
  func finish(_ session: LessonSession, practice: PracticeStore) -> PlayOutcome? {
    guard session.answers.count == 2, case .choice(let index) = session.answers[0],
      pick.choices.indices.contains(index), case .line(let line) = pick.choices[index],
      case .tiles(let selection) = session.answers[1]
    else { return nil }
    let analyzer = Analyzer.cached(for: PracticeCard.card)
    let outcome = DailyDeal.result(hand: pick.tiles, pickedLine: line, passSelection: selection, analyzer: analyzer)
    result = outcome
    let played = scored ? practice.recordDailyDeal(day: day, result: outcome) : nil
    let streak = StreakLogic.display(practice.progress.streak, today: day).current
    shareText = DailyDeal.shareText(number: number, result: outcome, streak: streak)
    return played
  }
}

/// The Daily Deal result screen: both answers, XP and a Share button.
struct DailyDealResultView: View {
  @Environment(\.theme) private var theme
  let play: DailyDealPlay
  let session: LessonSession
  let outcome: PlayOutcome?
  let onContinue: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("Daily Deal #\(play.number)")
          .titleStyle()
          .foregroundStyle(theme.text)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("deal.title")
        if !play.scored {
          Label("You've played today's deal already, so this one is just practice.", systemImage: "arrow.counterclockwise")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.warning)
            .accessibilityIdentifier("deal.practice")
        }
        if let result = play.result {
          answerCard(
            title: "Pick a hand", mark: pickMark(result), detail: pickDetail(result),
            explanation: session.grades.first?.explanation ?? "", id: "deal.pick")
          answerCard(
            title: "Pass three", mark: result.pass.map(passEmoji).joined(), detail: "",
            explanation: session.grades.dropFirst().first?.explanation ?? "", id: "deal.pass")
          if let outcome, outcome.xp.total > 0 {
            Label("+\(outcome.xp.total) XP", systemImage: "star.circle.fill")
              .font(Typography.h2)
              .foregroundStyle(theme.success)
              .accessibilityIdentifier("deal.xp")
          }
          VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Share").tinyStyle().foregroundStyle(theme.textMuted)
            Text(play.shareText)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(theme.text)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(Spacing.md)
              .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
              .accessibilityIdentifier("deal.share.text")
            ShareLink(item: play.shareText) {
              Label("Share result", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButton(.secondary, size: .large))
            .accessibilityIdentifier("deal.share")
          }
        }
        Button("Continue", action: onContinue)
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("lesson.continue")
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func pickMark(_ result: DailyDeal.Result) -> String {
    switch result.pick {
    case .best, .good: return "✅"
    case .miss: return "❌"
    }
  }

  private func pickDetail(_ result: DailyDeal.Result) -> String {
    switch result.pick {
    case .best: return "Best hand, \(result.pickDistance) away"
    case .good: return "A good hand, \(result.pickDistance) away"
    case .miss: return "\(result.pickDistance) away"
    }
  }

  private func passEmoji(_ mark: DailyDeal.PassMark) -> String {
    switch mark {
    case .green: return "🟩"
    case .yellow: return "🟨"
    case .red: return "🟥"
    }
  }

  private func answerCard(title: String, mark: String, detail: String, explanation: String, id: String) -> some View {
    SectionCard(title) {
      HStack(spacing: Spacing.md) {
        Text(mark).font(.title)
        if !detail.isEmpty { Text(detail).font(Typography.body.weight(.semibold)).foregroundStyle(theme.text) }
      }
      Text(explanation)
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityIdentifier(id)
  }
}

/// The Daily Deal card on the Practice home.
struct DailyDealCard: View {
  @Environment(\.theme) private var theme
  @Environment(PracticeStore.self) private var practice
  let onPlay: () -> Void

  private var day: LocalDay { practice.today }
  private var played: DealRecord? { practice.progress.dailyDeals[day.description] }

  private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

  private var weekdayNote: String {
    let name = Self.weekdays[(day.isoWeekday - 1) % 7]
    switch day.isoWeekday {
    case 1: return "\(name): the easiest deal of the week"
    case 7: return "\(name): the hardest deal of the week"
    default: return name
    }
  }

  var body: some View {
    Button(action: onPlay) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(alignment: .firstTextBaseline) {
          Label("Daily Deal #\(DailyDeal.number(for: day))", systemImage: "rectangle.stack.fill")
            .font(Typography.h2)
            .foregroundStyle(theme.text)
          Spacer(minLength: Spacing.sm)
          if played != nil {
            Label("Played today", systemImage: "checkmark.circle.fill")
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.success)
              .accessibilityIdentifier("deal.played")
          }
        }
        Text(played == nil ? "One hand to choose and three tiles to pass. Everyone gets the same deal today." : "Come back for tomorrow's deal. You can play today's again for practice.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        HStack {
          Text(weekdayNote).font(Typography.tiny).foregroundStyle(theme.gold)
          Spacer()
          if played != nil { NextDealCountdown() }
        }
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(played == nil ? theme.gold : theme.border, lineWidth: played == nil ? 2 : 1))
      .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("daily.card")
  }
}

/// "Next deal in 5h 12m", counting down to local midnight.
struct NextDealCountdown: View {
  @Environment(\.theme) private var theme

  static func text(now: Date, calendar: Calendar = .current) -> String {
    let next = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) ?? now
    let seconds = max(0, Int(next.timeIntervalSince(now)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    return hours > 0 ? "Next deal in \(hours)h \(minutes)m" : "Next deal in \(max(1, minutes))m"
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      Text(Self.text(now: context.date))
        .font(Typography.tiny.monospacedDigit())
        .foregroundStyle(theme.textMuted)
        .accessibilityIdentifier("deal.countdown")
    }
  }
}

/// The end of a "Review mistakes" session.
struct ReviewResultView: View {
  @Environment(\.theme) private var theme
  let session: LessonSession
  let outcome: PlayOutcome?
  let onContinue: () -> Void

  var body: some View {
    let right = session.records.filter(\.correct).count
    VStack(spacing: Spacing.xl) {
      Spacer()
      Text("Review done")
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("complete.title")
      Text("\(right) of \(session.records.count) right")
        .font(Typography.h2)
        .foregroundStyle(theme.primary)
        .accessibilityIdentifier("review.score")
      Text("Ones you got right come back later; the others tomorrow.")
        .font(Typography.body)
        .foregroundStyle(theme.textMuted)
        .multilineTextAlignment(.center)
      if let outcome { Text("+\(outcome.xp.total) XP").font(Typography.h2).foregroundStyle(theme.success) }
      Spacer()
      Button("Continue", action: onContinue)
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("lesson.continue")
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity)
  }
}
