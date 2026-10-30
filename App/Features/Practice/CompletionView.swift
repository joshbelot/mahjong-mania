import MahjongCore
import SwiftUI

/// The end of a play: stars, XP, accuracy, and what it unlocked (SPEC §18.5).
struct CompletionView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let session: LessonSession
  let outcome: PlayOutcome
  let onContinue: () -> Void
  let onReplay: () -> Void
  @Environment(PracticeStore.self) private var practice
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var fanfare = 0
  @State private var flash = false

  /// A three-star lesson: the big finish (SPEC §19.3).
  private var perfect: Bool { kind == .lesson && !session.gold && outcome.stars == 3 }

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
        if !typeSize.isAccessibilitySize && kind != .review {
          SunnyView(expression: outcome.passed && (kind != .lesson || outcome.stars >= 2 || session.gold) ? .cheering : .hello, size: 84, animated: true)
        }
        Text(title)
          .titleStyle()
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.center)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("complete.title")
        if kind == .lesson && !session.gold {
          StarsView(count: outcome.stars, animated: true)
            .background { if perfect { PerfectGlow(flash: flash) } }
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
        if perfect {
          Label("\(practice.progress.counters.threeStarLessons) perfect \(practice.progress.counters.threeStarLessons == 1 ? "lesson" : "lessons") so far", systemImage: "star.circle.fill")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(theme.gold)
            .accessibilityIdentifier("complete.perfectcount")
        }
        Text(subtitle)
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("complete.subtitle")

        HStack(spacing: Spacing.md) {
          xpStat
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
    .overlay { if perfect { ConfettiView(gold: true).ignoresSafeArea() } }
    .sound(trigger: fanfare) { $0 > 0 && perfect ? .perfect : nil }
    .hapticOnChange(trigger: fanfare) { $0 > 0 && perfect ? .success : nil }
    .task {
      guard perfect else { return }
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 700))
      fanfare += 1
      withAnimation(.easeOut(duration: 0.7)) { flash = true }
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

  /// The XP total counts up (0.8 s) while the stars land; it is simply there with Reduce Motion.
  private var xpStat: some View {
    VStack(spacing: 2) {
      CountingText(target: outcome.xp.total, prefix: "+")
        .font(Typography.h2.monospacedDigit())
        .foregroundStyle(theme.text)
        .accessibilityIdentifier("complete.xp")
      Text("XP").tinyStyle().foregroundStyle(theme.textMuted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Spacing.md)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
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
    if let unit = outcome.unitGold {
      Label("Unit \(unit) is gold", systemImage: "crown.fill")
        .font(Typography.body.weight(.semibold))
        .foregroundStyle(theme.gold)
        .multilineTextAlignment(.center)
    }
  }
}

/// Three stars, filled up to `count`. With `animated`, each filled star bounces in 0.25 s after the last,
/// with a rising chime (a plain fade with Reduce Motion).
struct StarsView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  @Environment(\.soundsEnabled) private var soundsEnabled
  let count: Int
  var size: CGFloat = 44
  var animated = false
  @State private var shown = 0

  var body: some View {
    HStack(spacing: Spacing.sm) {
      ForEach(1...3, id: \.self) { index in
        let filled = index <= (animated ? shown : count)
        Image(systemName: filled ? "star.fill" : "star")
          .font(.system(size: size))
          .foregroundStyle(filled ? theme.gold : theme.border)
          .symbolEffect(.bounce, options: .nonRepeating, value: filled && animated && !reduceMotion ? 1 : 0)
      }
    }
    .task {
      guard animated else { return }
      for index in 1...max(1, count) where count > 0 {
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 250))
        withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.45)) { shown = index }
        if soundsEnabled, let sound = Sound(rawValue: "star\(min(index, 3))") { SoundPlayer.shared.play(sound) }
      }
    }
  }
}

/// A number that counts up from 0 to `target` (the final value is announced at once to VoiceOver).
struct CountingText: View {
  @Environment(\.reduceMotion) private var reduceMotion
  let target: Int
  var prefix = ""
  @State private var shown = 0

  var body: some View {
    Text("\(prefix)\(reduceMotion ? target : shown)")
      .accessibilityLabel("\(prefix)\(target)")
      .task {
        guard !reduceMotion, target > 0 else { return }
        let steps = min(target, 30)
        for step in 1...steps {
          try? await Task.sleep(for: .milliseconds(800 / steps))
          shown = target * step / steps
        }
        shown = target
      }
  }
}

/// A ring that flashes out from behind the stars on a three-star finish; a still gold glow with Reduce Motion.
struct PerfectGlow: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let flash: Bool

  var body: some View {
    ZStack {
      Circle().fill(theme.gold.opacity(0.22)).blur(radius: 18).frame(width: 190, height: 190)
      if !reduceMotion {
        Circle()
          .strokeBorder(theme.gold, lineWidth: 5)
          .frame(width: 120, height: 120)
          .scaleEffect(flash ? 2.4 : 0.6)
          .opacity(flash ? 0 : 0.9)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
