import MahjongCore
import SwiftUI

enum FreePlayMode: Hashable {
  case pickAHand, charleston

  var title: String {
    switch self {
    case .pickAHand: return "Pick-a-Hand"
    case .charleston: return "Charleston Pass"
    }
  }

  var type: ExerciseType {
    switch self {
    case .pickAHand: return .pickHand
    case .charleston: return .passThree
    }
  }
}

/// Free play (SPEC §18.8): endless Pick-a-Hand or Charleston Pass deals on the Practice Card or your active
/// card, at Easy, Normal or Hard, with the same feedback, hints-free scoring and XP as the path.
struct FreePlayView: View {
  @Environment(\.theme) private var theme
  @Environment(PracticeStore.self) private var practice
  @Environment(SettingsStore.self) private var settings
  @Environment(CardsStore.self) private var cards
  let mode: FreePlayMode

  @State private var useActiveCard = false
  @State private var difficulty = 2
  @State private var session: LessonSession?
  @State private var seed: UInt64 = 0
  @State private var streak = 0
  /// Only the first answer to a deal moves the streak and pays XP, so replaying a deal cannot farm either.
  @State private var firstAttempt = true
  @State private var dealt = false
  @State private var celebrations: [CelebrationItem] = []
  @State private var celebrationIndex = 0

  private var activeCard: Card? {
    let id = settings.settings.activeCardID
    guard id != PracticeCard.card.id, let card = cards.card(id: id), !card.lines.isEmpty else { return nil }
    return card
  }

  private var card: Card { useActiveCard ? (activeCard ?? PracticeCard.card) : PracticeCard.card }
  private var best: Int {
    mode == .pickAHand ? practice.progress.freePlay.pickStreakBest : practice.progress.freePlay.charlestonStreakBest
  }

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          status
          options
          if let session, let exercise = session.exercise {
            ExerciseView(session: session, exercise: exercise)
              .id(seed)
          }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }
    .overlay {
      if celebrations.indices.contains(celebrationIndex) {
        CelebrationView(item: celebrations[celebrationIndex], isLast: celebrationIndex + 1 >= celebrations.count) {
          if celebrationIndex + 1 < celebrations.count { celebrationIndex += 1 } else { celebrations = [] }
        }
        .id(celebrations[celebrationIndex].id)
      }
    }
    .navigationTitle(mode.title)
    .navigationBarTitleDisplayMode(.inline)
    .sound(trigger: session?.answerCount ?? 0) { count in
      count > 0 ? (session?.lastCorrect == true ? .right : .wrong) : nil
    }
    .hapticOnChange(trigger: session?.answerCount ?? 0) { count in
      count > 0 ? (session?.lastCorrect == true ? .success : .warning) : nil
    }
    .onAppear { if session == nil { newDeal() } }
    .onChange(of: session?.answerCount ?? 0) { _, count in
      if count > 0, let session { recordResult(session) }
    }
    .onChange(of: difficulty) { newDeal() }
    .onChange(of: useActiveCard) { newDeal() }
  }

  // MARK: Pieces

  private var status: some View {
    AdaptiveStack(spacing: Spacing.sm) {
      Text("Deal #\(seed)")
        .font(Typography.small.monospacedDigit())
        .foregroundStyle(theme.textMuted)
        .accessibilityIdentifier("free.seed")
      Spacer(minLength: Spacing.sm)
      Text("Streak \(streak) · Best \(best)")
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.gold)
        .accessibilityIdentifier("free.streak")
    }
  }

  private var options: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      if activeCard != nil {
        SegmentedPicker("Card", selection: $useActiveCard, options: [false, true]) { $0 ? "My card" : "Practice Card" }
          .accessibilityIdentifier("free.card")
      }
      SegmentedPicker("Difficulty", selection: $difficulty, options: [1, 2, 3]) {
        switch $0 {
        case 1: return "Easy"
        case 2: return "Normal"
        default: return "Hard"
        }
      }
      .accessibilityIdentifier("free.difficulty")
    }
  }

  @ViewBuilder
  private var bottomBar: some View {
    VStack(spacing: 0) {
      if let session {
        if session.phase == .feedback, let feedback = session.feedback {
          FeedbackBar(
            feedback: feedback, continueTitle: "Next deal", secondaryTitle: "Try again",
            onSecondary: { tryAgain() }, onContinue: { newDeal() })
        } else if session.canCheck && !session.commitsOnTap {
          Button("Check") { withAnimation(.snappy(duration: 0.25)) { session.check() } }
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .accessibilityIdentifier("lesson.check")
        } else if session.exercise?.selectCount ?? 0 > 0 {
          Button("Check") {}
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .disabled(true)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .accessibilityIdentifier("lesson.check")
        }
      }
    }
    .frame(maxWidth: .infinity)
    .background(theme.bg)
  }

  // MARK: Actions

  private func newDeal() {
    // UI tests pin the first deal only, so "Next deal" really is a new one.
    seed = (dealt ? nil : LaunchOptions.practiceSeed()) ?? UInt64.random(in: 1...999_999)
    dealt = true
    firstAttempt = true
    start()
  }

  private func tryAgain() {
    firstAttempt = false
    start()
  }

  private func start() {
    let id = ExerciseID(type: mode.type, seed: seed, difficulty: difficulty)
    session = LessonSession(title: mode.title, ids: [id], card: card, seed: seed)
  }

  /// Called when the session reaches feedback, however the answer was committed (tap or Check).
  private func recordResult(_ session: LessonSession) {
    guard session.phase == .feedback, let record = session.records.last, firstAttempt else { return }
    firstAttempt = false
    streak = record.correct ? streak + 1 : 0
    mode == .pickAHand ? practice.setBestStreak(pickAHand: streak) : practice.setBestStreak(charleston: streak)
    let result = practice.recordFreePlay(record, queueMiss: !useActiveCard || activeCard == nil)
    var items: [CelebrationItem] = []
    if let level = result.levelUp { items.append(.levelUp(level: level.level, title: level.title)) }
    items += result.newBadges.map { .badge($0) }
    if !items.isEmpty { celebrations = items; celebrationIndex = 0 }
  }
}
