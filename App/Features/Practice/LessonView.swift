import MahjongCore
import SwiftUI

/// The full-screen lesson player (SPEC §18.5): top bar, intro card, question, feedback, completion.
struct LessonView: View {
  @Environment(\.theme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(PracticeStore.self) private var practice
  @State private var session: LessonSession
  @State private var outcome: PlayOutcome?
  @State private var confirmQuit = false
  let onClose: () -> Void
  /// Starts another play of the same node (Play again / Try again).
  let onReplay: () -> Void

  init(session: LessonSession, onClose: @escaping () -> Void, onReplay: @escaping () -> Void) {
    _session = State(initialValue: session)
    self.onClose = onClose
    self.onReplay = onReplay
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
    .onChange(of: session.phase) { _, phase in
      if phase == .finished, outcome == nil {
        outcome = practice.apply(session.playResult(day: practice.today, hour: practice.hour))
      }
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
          .accessibilityLabel("\(session.combo) in a row")
          .accessibilityIdentifier("lesson.combo")
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
      if let outcome {
        CompletionView(
          session: session, outcome: outcome, onContinue: onClose, onReplay: onReplay)
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
        LessonIllustration(nodeID: session.node.id)
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
  let feedback: LessonSession.Feedback
  let onContinue: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
        Image(systemName: feedback.correct ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
          .font(.title2)
          .foregroundStyle(feedback.correct ? theme.success : theme.warning)
          .accessibilityHidden(true)
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
      Button("Continue", action: onContinue)
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("lesson.continue")
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
