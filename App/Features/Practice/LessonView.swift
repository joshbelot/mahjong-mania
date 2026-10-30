import MahjongCore
import SwiftUI

/// The full-screen lesson player (SPEC §18.5): top bar, intro card, question, feedback, completion.
struct LessonView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  @Environment(PracticeStore.self) private var practice
  @State private var session: LessonSession
  @State private var outcome: PlayOutcome?
  @State private var applied = false
  @State private var confirmQuit = false
  @State private var celebrations: [CelebrationItem] = []
  @State private var celebrationIndex = 0
  @State private var afterCelebrations: (() -> Void)?
  let onClose: () -> Void
  /// Starts another play of the same node (Play again / Try again).
  let onReplay: () -> Void
  /// Plays that are not a path node (Daily Deal, review) record their own result and show their own end screen.
  var applyResult: ((LessonSession) -> PlayOutcome?)?
  var completion: ((LessonSession, PlayOutcome?, @escaping () -> Void) -> AnyView)?

  init(
    session: LessonSession, onClose: @escaping () -> Void, onReplay: @escaping () -> Void = {},
    applyResult: ((LessonSession) -> PlayOutcome?)? = nil,
    completion: ((LessonSession, PlayOutcome?, @escaping () -> Void) -> AnyView)? = nil
  ) {
    _session = State(initialValue: session)
    self.onClose = onClose
    self.onReplay = onReplay
    self.applyResult = applyResult
    self.completion = completion
  }

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      VStack(spacing: 0) {
        if session.phase != .finished { topBar }
        content
      }
      .frame(maxWidth: 640)
    }
    .confirmationDialog("Quit this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
      Button("Quit lesson", role: .destructive, action: onClose)
        .accessibilityIdentifier("lesson.quit.confirm")
      Button("Keep going", role: .cancel) {}
    } message: {
      Text("Your progress in it will be lost.")
    }
    .overlay {
      if celebrations.indices.contains(celebrationIndex) {
        CelebrationView(
          item: celebrations[celebrationIndex], isLast: celebrationIndex + 1 >= celebrations.count
        ) { advanceCelebrations() }
        .id(celebrations[celebrationIndex].id)
        .transition(.opacity)
      }
    }
    .sound(trigger: session.answerCount) { _ in
      session.feedback?.comboBonus ?? 0 > 0 ? .combo : (session.lastCorrect ? .right : .wrong)
    }
    .hapticOnChange(trigger: session.answerCount) { _ in session.lastCorrect ? .success : .warning }
    .onChange(of: session.phase) { _, phase in
      if phase == .finished, !applied {
        applied = true
        if let applyResult {
          outcome = applyResult(session)
        } else {
          outcome = practice.apply(session.playResult(day: practice.today, hour: practice.hour))
        }
      }
    }
  }

  // MARK: Celebrations

  /// Shows a new level, badges and streak news, one screen at a time, and then does `action`.
  private func runCelebrations(then action: @escaping () -> Void) {
    var items = outcome.map(Celebrations.items(for:)) ?? []
    if !practice.progress.goalChosen {
      // The first time, the goal screen says the day's goal is done and asks for the real one: no separate "goal met".
      items.removeAll { if case .goalMet = $0 { return true } else { return false } }
      items.append(.chooseGoal)
    }
    guard !items.isEmpty else { return action() }
    afterCelebrations = action
    celebrationIndex = 0
    withAnimation(.easeIn(duration: 0.2)) { celebrations = items }
  }

  private func advanceCelebrations() {
    if celebrationIndex + 1 < celebrations.count {
      withAnimation(.easeInOut(duration: 0.2)) { celebrationIndex += 1 }
    } else {
      let action = afterCelebrations
      celebrations = []
      afterCelebrations = nil
      action?()
    }
  }

  // MARK: Top bar

  private var topBar: some View {
    HStack(spacing: Spacing.md) {
      Button {
        if session.hasProgress { confirmQuit = true } else { onClose() }
      } label: {
        Image(systemName: "xmark")
          .font(.headline)
          .foregroundStyle(theme.textMuted)
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel("Close lesson")
      .accessibilityIdentifier("lesson.close")

      ProgressBar(fraction: session.progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(session.answered) of \(session.total) answered")

      if session.combo >= 3 {
        Label("\(session.combo)", systemImage: "flame.fill")
          .font(Typography.small.weight(.bold).monospacedDigit())
          .foregroundStyle(theme.accent)
          .pop(trigger: session.combo)
          .background { ComboBurst(combo: session.combo) }
          .accessibilityLabel("\(session.combo) in a row")
          .accessibilityIdentifier("lesson.combo")
      }
      if session.cheatSheetAllowed && session.phase != .intro && session.phase != .finished {
        TilesButton()
      }
      if session.hintsAllowed && session.phase != .intro {
        Button {
          session.useHint()
        } label: {
          Image(systemName: "lightbulb.fill")
            .font(.headline)
            .foregroundStyle(session.hintAvailable ? theme.gold : theme.textFaint)
            .frame(width: 44, height: 44)
        }
        .disabled(!session.hintAvailable)
        .accessibilityLabel("Hint")
        .accessibilityHint("Gives you a clue; the question then pays less XP and can't earn three stars")
        .accessibilityIdentifier("lesson.hint.button")
      }
    }
    .padding(.horizontal, Spacing.sm)
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    switch session.phase {
    case .intro:
      intro
    case .answering, .feedback:
      if let exercise = session.exercise {
        ScrollViewReader { proxy in
          ScrollView {
            ExerciseView(session: session, exercise: exercise)
              .id(exercise.id)
              .padding(.horizontal, Spacing.lg)
              .padding(.vertical, Spacing.lg)
              .padding(.bottom, session.phase == .feedback ? 8 : 0)
          }
          .onChange(of: session.index) { proxy.scrollTo(exercise.id, anchor: .top) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
      }
    case .finished:
      if let completion {
        completion(session, outcome) { runCelebrations(then: onClose) }
      } else if let outcome {
        CompletionView(
          session: session, outcome: outcome, onContinue: { runCelebrations(then: onClose) },
          onReplay: { runCelebrations(then: onReplay) })
      } else {
        ProgressView().frame(maxHeight: .infinity)
      }
    }
  }

  @ViewBuilder
  private var bottomBar: some View {
    VStack(spacing: 0) {
      if session.phase == .feedback, let feedback = session.feedback {
        FeedbackBar(feedback: feedback) {
          session.next()
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
      } else if session.exercise.map({ $0.id.type != .keepOrPass && !session.commitsOnTap }) ?? false {
        Button("Check") { withAnimation(.snappy(duration: 0.25)) { session.check() } }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .disabled(!session.canCheck)
          .padding(.horizontal, Spacing.lg)
          .padding(.vertical, Spacing.md)
          .accessibilityIdentifier("lesson.check")
      }
    }
    .frame(maxWidth: .infinity)
    .background(theme.bg)
  }

  private var intro: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("Unit \(session.node.unit) · \(Curriculum.unit(session.node.unit)?.title ?? "")")
          .tinyStyle()
          .foregroundStyle(theme.textMuted)
        Text(session.node.title)
          .titleStyle()
          .foregroundStyle(theme.text)
          .accessibilityAddTraits(.isHeader)
        Text(session.node.intro)
          .font(Typography.body)
          .foregroundStyle(theme.text)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: Spacing.lg) {
          SunnyView(expression: .hello, size: 72)
          UnitArt(unit: session.node.unit)
        }
        LessonIllustration(nodeID: session.node.id)
        if session.node.unit == 1 {
          TilesButton(style: .label)
        }
        Text("\(session.node.count) quick questions. Mistakes are fine; they come back at the end.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        Button("Let's go") { withAnimation(.snappy(duration: 0.2)) { session.begin() } }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("lesson.start")
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// The thin progress bar along the top of a lesson.
struct ProgressBar: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let fraction: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.border)
        Capsule()
          .fill(theme.primary)
          .frame(width: max(0, min(1, fraction)) * geometry.size.width)
          .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fraction)
      }
    }
    .frame(height: 12)
  }
}

/// "Nice!" or "Not quite" with the right answer and why, and one Continue button.
struct FeedbackBar: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let feedback: LessonSession.Feedback
  var continueTitle = "Continue"
  var secondaryTitle: String?
  var onSecondary: (() -> Void)?
  let onContinue: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
        if feedback.correct {
          DrawnCheckmark(color: theme.success)
        } else {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.title2)
            .foregroundStyle(theme.warning)
            .accessibilityHidden(true)
        }
        if !typeSize.isAccessibilitySize {
          SunnyView(expression: feedback.correct ? .cheering : .oops, size: 30)
            .frame(width: 40, height: 36)
        }
        Text(feedback.title)
          .font(Typography.h2)
          .foregroundStyle(theme.text)
          .accessibilityIdentifier("lesson.feedback.title")
        Spacer(minLength: Spacing.sm)
        if feedback.xp > 0 {
          Text("+\(feedback.xp) XP")
            .font(Typography.small.weight(.bold).monospacedDigit())
            .foregroundStyle(theme.success)
            .accessibilityIdentifier("lesson.feedback.xp")
        }
      }
      CappedScroll(maxHeight: 240) {
        VStack(alignment: .leading, spacing: Spacing.sm) {
          if !feedback.correct && !feedback.correctAnswer.isEmpty {
            Text("Right answer: \(feedback.correctAnswer)")
              .font(Typography.body.weight(.semibold))
              .foregroundStyle(theme.text)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("lesson.feedback.answer")
          }
          if !feedback.explanation.isEmpty {
            Text(feedback.explanation)
              .font(Typography.small)
              .foregroundStyle(theme.textMuted)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("lesson.feedback.explanation")
          }
          if feedback.comboBonus > 0 {
            Label("\(feedback.comboBonus) bonus XP for a streak of right answers", systemImage: "flame.fill")
              .font(Typography.small.weight(.semibold))
              .foregroundStyle(theme.accent)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      Button(continueTitle, action: onContinue)
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("lesson.continue")
      if let secondaryTitle, let onSecondary {
        Button(secondaryTitle, action: onSecondary)
          .buttonStyle(PrimaryButton(.secondary, size: .large))
          .accessibilityIdentifier("lesson.secondary")
      }
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      (feedback.correct ? theme.success : theme.warning).opacity(0.16)
        .background(theme.bg)
    )
    .overlay(alignment: .top) {
      Rectangle().fill(feedback.correct ? theme.success : theme.warning).frame(height: 2)
    }
    .overlay(alignment: .topTrailing) {
      FloatingXP(amount: feedback.xp)
        .padding(.trailing, Spacing.xl)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("lesson.feedback")
  }
}

/// A scroll view that is only as tall as its content, up to `maxHeight`.
struct CappedScroll<Content: View>: View {
  let maxHeight: CGFloat
  @ViewBuilder let content: () -> Content
  @State private var height: CGFloat = 0

  var body: some View {
    ScrollView {
      content()
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: CappedScrollHeightKey.self, value: proxy.size.height)
          })
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: height == 0 ? nil : min(height, maxHeight))
    .onPreferenceChange(CappedScrollHeightKey.self) { height = $0 }
  }
}

private struct CappedScrollHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A brighter burst round the flame when the run reaches 5, 10 or 15 (nothing with Reduce Motion).
struct ComboBurst: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let combo: Int
  @State private var expanded = false

  var body: some View {
    if combo > 0 && combo % 5 == 0 && !reduceMotion {
      Circle()
        .strokeBorder(theme.gold, lineWidth: 3)
        .scaleEffect(expanded ? 2.6 : 0.6)
        .opacity(expanded ? 0 : 0.9)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { expanded = true } }
        .id(combo)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }
}
