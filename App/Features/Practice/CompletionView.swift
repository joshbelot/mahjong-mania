import MahjongCore
import SwiftUI

/// The end of a play: stars, XP, accuracy, and what it unlocked (SPEC §18.5).
struct CompletionView: View {
  @Environment(\.theme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let session: LessonSession
  let outcome: PlayOutcome
  let onContinue: () -> Void
  let onReplay: () -> Void

  private var kind: NodeKind { session.node.kind }
  private var title: String {
    switch kind {
    case .checkpoint:
      if session.testOut { return outcome.passed ? "You tested out!" : "Not this time" }
      return outcome.passed ? "Checkpoint passed!" : "Almost there"
    case .review: return "Review done"
    case .lesson:
      if session.gold { return outcome.passed ? "Gold!" : "Close to gold" }
      return outcome.stars == 3 ? "Perfect!" : "Lesson complete"
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: Spacing.xl) {
        Text(title)
          .titleStyle()
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.center)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("complete.title")
        if kind == .lesson && !session.gold {
          StarsView(count: outcome.stars)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(outcome.stars) of 3 stars")
            .accessibilityIdentifier("complete.stars")
          if outcome.improvedStars && outcome.previousStars > 0 {
            Label("New best!", systemImage: "sparkles")
              .font(Typography.body.weight(.semibold))
              .foregroundStyle(theme.gold)
              .accessibilityIdentifier("complete.newbest")
          }
        } else if kind == .checkpoint {
          Image(systemName: outcome.passed ? "flag.checkered.circle.fill" : "flag.circle")
            .font(.system(size: 72))
            .foregroundStyle(outcome.passed ? theme.gold : theme.textMuted)
            .accessibilityHidden(true)
        }
        Text(subtitle)
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("complete.subtitle")

        HStack(spacing: Spacing.md) {
          stat("XP", "+\(outcome.xp.total)", id: "complete.xp")
          stat("Accuracy", "\(Int((outcome.accuracy * 100).rounded()))%", id: "complete.accuracy")
          stat("Time", timeText, id: "complete.time")
        }
        if outcome.bestCombo >= 3 {
          Label("Best run: \(outcome.bestCombo) in a row", systemImage: "flame.fill")
            .font(Typography.small.weight(.semibold))
            .foregroundStyle(theme.accent)
        }
        extras
        VStack(spacing: Spacing.md) {
          Button("Continue", action: onContinue)
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .accessibilityIdentifier("lesson.continue")
          if kind != .review {
            Button(replayTitle, action: onReplay)
              .buttonStyle(PrimaryButton(.secondary, size: .large))
              .accessibilityIdentifier("lesson.playagain")
          }
        }
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity)
    }
  }

  private var replayTitle: String {
    kind == .checkpoint && !outcome.passed ? "Try again" : "Play again"
  }

  private var subtitle: String {
    switch kind {
    case .checkpoint:
      let right = LessonScoring.firstTryCorrect(session.records)
      let asked = session.records.filter { !$0.isReask }.count
      if outcome.passed {
        if session.testOut {
          let open = Curriculum.unit(session.node.unit + 1).map { "Unit \($0.id) is open." } ?? "You've finished the path."
          return "You got \(right) of \(asked) and skipped ahead. \(open)"
        }
        if let unit = outcome.unitFinished, let next = Curriculum.unit(unit + 1) {
          return "\(right) of \(asked) right. Unit \(next.id), \(next.title), is open."
        }
        return "\(right) of \(asked) right. You've finished the path."
      }
      let needed = session.testOut ? Curriculum.testOutPassMark : Curriculum.checkpointPassMark
      return "\(right) of \(asked) right; you need \(needed). Try again whenever you like, or practise a lesson first."
    case .review:
      return "Good practice. Questions you got right come back later; the others tomorrow."
    case .lesson:
      if session.gold {
        return outcome.passed ? "Every question at a harder level. This lesson is gold." : "Gold needs 90% right first time with no hints."
      }
      switch outcome.stars {
      case 3: return "Every question right first time."
      case 2: return "Nicely done. A perfect run earns three stars."
      default: return "You finished it. Play again for more stars."
      }
    }
  }

  private var timeText: String {
    let seconds = outcome.seconds
    return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
  }

  private func stat(_ label: String, _ value: String, id: String) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(Typography.h2.monospacedDigit())
        .foregroundStyle(theme.text)
        .accessibilityIdentifier(id)
      Text(label).tinyStyle().foregroundStyle(theme.textMuted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Spacing.md)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var extras: some View {
    VStack(spacing: Spacing.sm) {
      if let level = outcome.levelUp {
        Label("Level \(level.level): \(level.title)", systemImage: "arrow.up.circle.fill")
          .foregroundStyle(theme.primary)
          .accessibilityIdentifier("complete.levelup")
      }
      ForEach(outcome.newBadges, id: \.self) { badge in
        Label("New badge: \(badge.title)", systemImage: badge.symbol)
          .foregroundStyle(theme.gold)
          .accessibilityIdentifier("complete.badge.\(badge.rawValue)")
      }
      if outcome.goalJustMet {
        Label("Daily goal met", systemImage: "checkmark.seal.fill")
          .foregroundStyle(theme.success)
          .accessibilityIdentifier("complete.goal")
      }
      if let unit = outcome.unitGold {
        Label("Unit \(unit) is gold", systemImage: "crown.fill")
          .foregroundStyle(theme.gold)
      }
    }
    .font(Typography.body.weight(.semibold))
    .multilineTextAlignment(.center)
  }
}

/// Three stars, filled up to `count`.
struct StarsView: View {
  @Environment(\.theme) private var theme
  let count: Int
  var size: CGFloat = 44

  var body: some View {
    HStack(spacing: Spacing.sm) {
      ForEach(1...3, id: \.self) { index in
        Image(systemName: index <= count ? "star.fill" : "star")
          .font(.system(size: size))
          .foregroundStyle(index <= count ? theme.gold : theme.border)
      }
    }
  }
}
