import MahjongCore
import SwiftUI

/// The Speed Round (SPEC §18.8): 60 seconds of keep-or-pass decisions (+1 s right, -2 s wrong), or 30
/// untimed questions with "No timer in Speed Round" on.
@MainActor
@Observable
final class SpeedRoundModel {
  enum Phase { case ready, running, finished }

  private(set) var phase = Phase.ready
  private(set) var clock: SpeedClock
  private(set) var question: SpeedQuestion?
  /// The result of the last answer: the line to show under the next question.
  private(set) var lastNote: (text: String, correct: Bool)?
  private(set) var flashCount = 0
  private(set) var lastCorrect = false
  private(set) var outcome: PlayOutcome?
  private(set) var newBest = false
  @ObservationIgnored private var stream: SpeedStream
  @ObservationIgnored private var timer: Task<Void, Never>?
  let seed: UInt64
  let timed: Bool

  init(timed: Bool, seed: UInt64) {
    self.timed = timed
    self.seed = seed
    clock = SpeedClock(timed: timed)
    stream = SpeedStream(seed: seed, analyzer: Analyzer.cached(for: PracticeCard.card))
  }

  func start() {
    guard phase == .ready else { return }
    phase = .running
    question = stream.next()
    guard timed else { return }
    timer = Task { [weak self] in
      var last = Date()
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        guard let self, self.phase == .running else { return }
        let now = Date()
        self.clock.tick(now.timeIntervalSince(last))
        last = now
        if self.clock.isOver { self.finish(); return }
      }
    }
  }

  func answerKeep(_ keep: Bool) {
    guard phase == .running, case .keepPass(_, _, _, let right, let why)? = question else { return }
    record(correct: keep == right, note: why)
  }

  func answerChoice(_ index: Int) {
    guard phase == .running, case .bonus(let exercise)? = question else { return }
    let grade = Exercises.grade(exercise, answer: .choice(index), analyzer: Analyzer.cached(for: PracticeCard.card))
    record(correct: grade.correct, note: grade.correct ? grade.explanation : "Right answer: \(grade.correctAnswer). " + grade.explanation)
  }

  private func record(correct: Bool, note: String) {
    clock.answer(correct: correct)
    lastCorrect = correct
    flashCount += 1
    lastNote = (note, correct)
    if clock.isOver {
      finish()
    } else {
      question = stream.next()
    }
  }

  private func finish() {
    guard phase == .running else { return }
    timer?.cancel()
    phase = .finished
    question = nil
  }

  /// Saves the round (call once, when `phase` becomes `.finished`).
  func record(in practice: PracticeStore) {
    guard outcome == nil else { return }
    let result = practice.recordSpeedRound(right: clock.right, bestRun: clock.bestRun)
    outcome = result.outcome
    newBest = result.newBest
  }

  func cancel() { timer?.cancel() }
}

struct SpeedRoundView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  @Environment(PracticeStore.self) private var practice
  @Environment(SettingsStore.self) private var settings
  @State private var model: SpeedRoundModel
  @State private var celebrations: [CelebrationItem] = []
  @State private var celebrationIndex = 0
  let onClose: () -> Void
  let onReplay: () -> Void

  init(timed: Bool, onClose: @escaping () -> Void, onReplay: @escaping () -> Void) {
    _model = State(initialValue: SpeedRoundModel(timed: timed, seed: LaunchOptions.practiceSeed() ?? UInt64.random(in: 1...999_999_999)))
    self.onClose = onClose
    self.onReplay = onReplay
  }

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      VStack(spacing: 0) {
        topBar
        switch model.phase {
        case .ready: ready
        case .running: running
        case .finished: finished
        }
      }
      .frame(maxWidth: 640)
    }
    .overlay {
      if celebrations.indices.contains(celebrationIndex) {
        CelebrationView(item: celebrations[celebrationIndex], isLast: celebrationIndex + 1 >= celebrations.count) {
          if celebrationIndex + 1 < celebrations.count { celebrationIndex += 1 } else { celebrations = []; onClose() }
        }
        .id(celebrations[celebrationIndex].id)
      }
    }
    .sound(trigger: model.flashCount) { _ in model.lastCorrect ? .right : .wrong }
    .hapticOnChange(trigger: model.flashCount) { _ in model.lastCorrect ? .success : .warning }
    .onChange(of: model.phase) { _, phase in
      if phase == .finished { model.record(in: practice) }
    }
    .onDisappear { model.cancel() }
  }

  // MARK: Chrome

  private var topBar: some View {
    HStack(spacing: Spacing.md) {
      Button {
        model.cancel()
        onClose()
      } label: {
        Image(systemName: "xmark").font(.headline).foregroundStyle(theme.textMuted).frame(width: 44, height: 44)
      }
      .accessibilityLabel("Close")
      .accessibilityIdentifier("speed.close")
      Spacer()
      if model.phase == .running {
        if model.timed {
          Text(String(format: "%.0f", model.clock.remaining.rounded(.up)))
            .font(.title.weight(.bold).monospacedDigit())
            .foregroundStyle(model.clock.remaining <= 10 ? theme.warning : theme.text)
            .accessibilityLabel("Seconds left")
            .accessibilityValue("\(Int(model.clock.remaining.rounded(.up)))")
            .accessibilityIdentifier("speed.timer")
        } else {
          Text("\(model.clock.answered + 1) of \(SpeedClock.untimedQuestions)")
            .font(Typography.h2.monospacedDigit())
            .foregroundStyle(theme.text)
            .accessibilityIdentifier("speed.progress")
        }
        Spacer()
        Label("\(model.clock.right)", systemImage: "checkmark.circle.fill")
          .font(Typography.h2.monospacedDigit())
          .foregroundStyle(theme.success)
          .accessibilityLabel("Right")
          .accessibilityValue("\(model.clock.right)")
          .accessibilityIdentifier("speed.score")
      }
    }
    .padding(.horizontal, Spacing.sm)
    .frame(minHeight: 52)
  }

  // MARK: Ready

  private var ready: some View {
    VStack(alignment: .leading, spacing: Spacing.lg) {
      Text("Speed Round")
        .titleStyle()
        .foregroundStyle(theme.text)
        .accessibilityAddTraits(.isHeader)
      Text(
        model.timed
          ? "Keep or pass each tile for the hand shown. You have 60 seconds: every right answer adds a second, every wrong one takes away two."
          : "Keep or pass each tile for the hand shown. Thirty questions, no clock."
      )
      .font(Typography.body)
      .foregroundStyle(theme.text)
      .fixedSize(horizontal: false, vertical: true)
      Text("Your best: \(practice.progress.speedBest)")
        .font(Typography.h2)
        .foregroundStyle(theme.gold)
        .accessibilityIdentifier("speed.best")
      Button(model.timed ? "Start the clock" : "Start") { model.start() }
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .accessibilityIdentifier("speed.start")
      Spacer()
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Running

  @ViewBuilder
  private var running: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        switch model.question {
        case .keepPass(let line, let rack, let tile, _, _):
          keepPass(line: line, rack: rack, tile: tile)
        case .bonus(let exercise):
          bonus(exercise)
        case nil:
          EmptyView()
        }
        note
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func keepPass(line: CardLine, rack: [Tile], tile: Tile) -> some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      DrillLineSummary(line: line)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
      Text("Keep it or pass it?").font(Typography.h2).foregroundStyle(theme.text)
      TileView(tile: tile, size: .large)
        .scaleEffect(1.4)
        .frame(width: 52 * 1.4, height: 70 * 1.4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .accessibilityIdentifier("speed.tile")
      HStack(spacing: Spacing.md) {
        Button { model.answerKeep(true) } label: { Text("Keep").font(Typography.h2).foregroundStyle(theme.text) }
          .buttonStyle(ChoiceButtonStyle())
          .accessibilityIdentifier("speed.keep")
        Button { model.answerKeep(false) } label: { Text("Pass").font(Typography.h2).foregroundStyle(theme.text) }
          .buttonStyle(ChoiceButtonStyle())
          .accessibilityIdentifier("speed.pass")
      }
    }
  }

  private func bonus(_ exercise: Exercise) -> some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      Text(exercise.prompt).font(Typography.h2).foregroundStyle(theme.text)
      HStack(spacing: 3) {
        ForEach(Array(exercise.tiles.enumerated()), id: \.offset) { entry in
          TileView(tile: entry.element, size: exercise.tiles.count > 1 ? .medium : .large)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Spacing.sm)
      VStack(spacing: Spacing.sm) {
        ForEach(Array(exercise.choices.enumerated()), id: \.offset) { entry in
          if case .text(let text) = entry.element {
            Button { model.answerChoice(entry.offset) } label: {
              Text(text).font(Typography.body.weight(.semibold)).foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ChoiceButtonStyle())
            .accessibilityIdentifier("speed.choice.\(entry.offset)")
          }
        }
      }
    }
  }

  @ViewBuilder
  private var note: some View {
    if let note = model.lastNote {
      Label(note.text, systemImage: note.correct ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
        .font(Typography.small)
        .foregroundStyle(note.correct ? theme.success : theme.warning)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("speed.note")
    }
  }

  // MARK: Finished

  private var finished: some View {
    ScrollView {
      VStack(spacing: Spacing.xl) {
        Text(model.newBest ? "New best!" : "Time's up")
          .titleStyle()
          .foregroundStyle(theme.text)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("speed.title")
        Text("\(model.clock.right)")
          .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(theme.primary)
          .accessibilityLabel("Right answers")
          .accessibilityValue("\(model.clock.right)")
          .accessibilityIdentifier("speed.result")
        HStack(spacing: Spacing.md) {
          stat("Best", "\(practice.progress.speedBest)")
          stat("Wrong", "\(model.clock.wrong)")
          stat("Best run", "\(model.clock.bestRun)")
          if let outcome = model.outcome { stat("XP", "+\(outcome.xp.total)") }
        }
        VStack(spacing: Spacing.md) {
          Button("Done") { finishAndClose() }
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .accessibilityIdentifier("speed.done")
          Button("Play again") {
            model.cancel()
            onReplay()
          }
          .buttonStyle(PrimaryButton(.secondary, size: .large))
          .accessibilityIdentifier("speed.again")
        }
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity)
    }
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(Typography.h2.monospacedDigit()).foregroundStyle(theme.text)
      Text(label).tinyStyle().foregroundStyle(theme.textMuted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Spacing.md)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }

  private func finishAndClose() {
    let items = model.outcome.map(Celebrations.items(for:)) ?? []
    if items.isEmpty {
      onClose()
    } else {
      celebrationIndex = 0
      celebrations = items
    }
  }
}
