import MahjongCore
import Observation
import SwiftUI

/// One play of a path node: the questions, the player's answers, hints, re-asked mistakes, combo and the
/// result handed to `PracticeStore`. All the rules live in MahjongCore; this class sequences them for the UI.
@MainActor
@Observable
final class LessonSession {
  enum Phase: Equatable { case intro, answering, feedback, finished }

  struct Item: Equatable {
    var id: ExerciseID
    var isReask: Bool
  }

  /// What the feedback sheet shows.
  struct Feedback: Equatable {
    var correct: Bool
    var title: String
    var correctAnswer: String
    var explanation: String
    var xp: Int
    var comboBonus: Int
  }

  let node: LessonSpec
  let gold: Bool
  let testOut: Bool
  let seed: UInt64
  @ObservationIgnored private let analyzer: Analyzer
  @ObservationIgnored private let fixed: [Exercise]?
  /// The player's rule book, for hard tile facts about their own table.
  @ObservationIgnored private let rules: RuleSet?
  @ObservationIgnored private var rng: SeededRandom
  @ObservationIgnored private let startedAt = Date()

  private(set) var items: [Item]
  private(set) var index = 0
  private(set) var phase: Phase
  private(set) var exercise: Exercise?
  private(set) var records: [AnswerRecord] = []
  /// The answers given, in order (the Daily Deal result reads them).
  private(set) var answers: [Answer] = []
  private(set) var grades: [Grade] = []
  private(set) var feedback: Feedback?
  private(set) var grade: Grade?
  private(set) var hint: Hint?
  private(set) var combo = 0
  private(set) var bestCombo = 0
  private(set) var xpEarned = 0
  /// Per tile of the keep-or-pass queue: did the player decide right?
  private(set) var decisionMarks: [Bool] = []
  /// Set when a joker was tapped, to shake it.
  private(set) var jokerShakes = 0
  private(set) var message: String?
  /// Counts every answer, and the wrong ones, so the screen can react (shake, sound, haptic).
  private(set) var answerCount = 0
  private(set) var wrongCount = 0
  private(set) var lastCorrect = false

  var choice: Int?
  var selectedTiles: [Int] = []
  private(set) var decisions: [Bool] = []
  private var hintUsed = false

  /// - Parameter review: due review exercises (review nodes only).
  init(
    node: LessonSpec, gold: Bool = false, testOut: Bool = false, seed: UInt64, review: [ExerciseID] = [],
    rules: RuleSet? = nil, showIntro: Bool
  ) {
    self.rules = rules
    self.node = node
    self.gold = gold
    self.testOut = testOut
    self.seed = seed
    fixed = nil
    analyzer = Analyzer.cached(for: PracticeCard.card)
    rng = SeededRandom(seed: seed ^ 0x5E55)
    items = Curriculum.exercises(for: node, seed: seed, gold: gold, review: review).map { Item(id: $0, isReask: false) }
    phase = showIntro && !node.intro.isEmpty && node.kind == .lesson && !gold ? .intro : .answering
    if phase == .answering { loadCurrent() }
  }

  /// A play outside the path: the given questions, no hints, no re-asks. `exercises` are used as they are
  /// (a Daily Deal); otherwise each of `ids` is made on `card`.
  init(title: String, ids: [ExerciseID] = [], exercises: [Exercise]? = nil, card: Card = PracticeCard.card, seed: UInt64 = 1) {
    let count = exercises?.count ?? ids.count
    node = LessonSpec.custom(id: "custom", title: title, count: count)
    gold = false
    testOut = false
    self.seed = seed
    fixed = exercises
    rules = nil
    // A card with no hands yet can't make questions; fall back to the Practice Card.
    analyzer = Analyzer.cached(for: card.lines.isEmpty ? PracticeCard.card : card)
    rng = SeededRandom(seed: seed ^ 0x5E55)
    items = (exercises?.map(\.id) ?? ids).map { Item(id: $0, isReask: false) }
    phase = .answering
    loadCurrent()
  }

  // MARK: Derived state

  var isCheckpoint: Bool { node.kind == .checkpoint }
  var hintsAllowed: Bool { node.kind != .checkpoint && !gold }
  var total: Int { items.count }
  var answered: Int { records.count }
  var progress: Double { total == 0 ? 0 : Double(answered) / Double(total) }
  var currentItem: Item? { items.indices.contains(index) ? items[index] : nil }
  var isReask: Bool { currentItem?.isReask ?? false }
  var hintAvailable: Bool { hintsAllowed && !hintUsed && phase == .answering }

  /// Single-choice answers (text, tile, number, line, yes/no) commit as soon as they are tapped. Only
  /// tile selections (pass one, pass three) keep a Check step (SPEC §19.3).
  var commitsOnTap: Bool {
    guard let exercise else { return false }
    if exercise.id.type == .keepOrPass { return true }
    return exercise.selectCount == 0 && !exercise.choices.isEmpty
  }

  /// Set for the Daily Deal's scored attempt, which hides the Tiles cheat sheet.
  var cheatSheetBlocked = false

  /// The Tiles button is hidden in gold lessons and the scored Daily Deal (the Speed Round is its own screen).
  var cheatSheetAllowed: Bool { !gold && !cheatSheetBlocked }

  var canCheck: Bool {
    guard let exercise, phase == .answering else { return false }
    if exercise.selectCount > 0 { return selectedTiles.count == exercise.selectCount }
    if exercise.id.type == .keepOrPass { return false }
    return choice != nil
  }

  var removedChoices: Set<Int> { Set(hint?.removeChoices ?? []) }
  var highlightedTiles: Set<Int> { Set(hint?.highlightTiles ?? []) }

  /// The tile of a keep-or-pass question being decided now.
  var currentQueueTile: Tile? {
    guard let exercise, exercise.id.type == .keepOrPass, decisions.count < exercise.queue.count else { return nil }
    return exercise.queue[decisions.count]
  }

  // MARK: Flow

  func begin() {
    guard phase == .intro else { return }
    phase = .answering
    loadCurrent()
  }

  private func loadCurrent() {
    guard let item = currentItem else {
      phase = .finished
      exercise = nil
      return
    }
    if let fixed, fixed.indices.contains(index) {
      exercise = fixed[index]
    } else {
      exercise = Exercises.make(item.id, analyzer: analyzer, rules: rules)
    }
    resetAnswerState()
  }

  private func resetAnswerState() {
    choice = nil
    selectedTiles = []
    decisions = []
    decisionMarks = []
    hint = nil
    hintUsed = false
    message = nil
    grade = nil
    feedback = nil
  }

  // MARK: Answering

  func toggleTile(_ position: Int) {
    guard phase == .answering, let exercise, exercise.selectCount > 0 else { return }
    guard exercise.canSelect(position: position) else {
      jokerShakes += 1
      message = "Jokers can't be passed"
      return
    }
    message = nil
    if let at = selectedTiles.firstIndex(of: position) {
      selectedTiles.remove(at: at)
    } else if selectedTiles.count < exercise.selectCount {
      selectedTiles.append(position)
    } else if exercise.selectCount == 1 {
      selectedTiles = [position]
    } else {
      message = "That's \(exercise.selectCount) already. Tap a selected tile to put it back."
    }
  }

  func select(choice index: Int) {
    guard phase == .answering, !removedChoices.contains(index) else { return }
    choice = index
    if commitsOnTap { check() }
  }

  /// Keep (true) or pass (false) the tile being decided.
  func decide(keep: Bool) {
    guard phase == .answering, let exercise, exercise.id.type == .keepOrPass,
      currentQueueTile != nil
    else { return }
    decisions.append(keep)
    if let right = exercise.shouldKeep(queueIndex: decisions.count - 1) { decisionMarks.append(right == keep) }
    if decisions.count == exercise.queue.count { check() }
  }

  func useHint() {
    guard hintAvailable, let exercise else { return }
    hint = Exercises.hint(for: exercise, analyzer: analyzer)
    hintUsed = true
    if let choice, removedChoices.contains(choice) { self.choice = nil }
  }

  func check() {
    guard phase == .answering, let exercise else { return }
    let answer: Answer
    if exercise.id.type == .keepOrPass {
      answer = .decisions(decisions)
    } else if exercise.selectCount > 0 {
      guard selectedTiles.count == exercise.selectCount else { return }
      answer = .tiles(selectedTiles)
    } else {
      guard let choice else { return }
      answer = .choice(choice)
    }
    let result = Exercises.grade(exercise, answer: answer, analyzer: analyzer)
    grade = result
    answerCount += 1
    lastCorrect = result.correct
    if !result.correct { wrongCount += 1 }
    let reask = currentItem?.isReask ?? false
    let record = AnswerRecord(exercise: exercise.id, correct: result.correct, usedHint: hintUsed, isReask: reask)
    records.append(record)
    answers.append(answer)
    grades.append(result)

    let before = LessonScoring.combo(records.dropLast())
    let after = LessonScoring.combo(records)
    let bonus = after.bonus - before.bonus
    combo = result.correct ? combo + 1 : 0
    bestCombo = max(bestCombo, after.best)
    let xp = XP.forAnswer(record) + bonus
    xpEarned += xp

    if !result.correct && !reask && !isCheckpoint, let id = currentItem?.id {
      items.append(Item(id: Curriculum.reask(id, seed: rng.next()), isReask: true))
    }
    feedback = Feedback(
      correct: result.correct, title: result.correct ? Self.praise.randomElement() ?? "Nice!" : "Not quite",
      correctAnswer: result.correctAnswer, explanation: result.explanation, xp: xp, comboBonus: bonus)
    phase = .feedback
  }

  func next() {
    guard phase == .feedback else { return }
    index += 1
    if index >= items.count {
      phase = .finished
      exercise = nil
      feedback = nil
      return
    }
    phase = .answering
    loadCurrent()
  }

  static let praise = ["Nice!", "Exactly!", "You've got it", "Great!", "Spot on!", "Well done!"]

  // MARK: Result

  var elapsedSeconds: Int { Int(Date().timeIntervalSince(startedAt)) }

  func playResult(day: LocalDay, hour: Int) -> PlayResult {
    PlayResult(
      nodeID: node.id, gold: gold, testOut: testOut, records: records, seconds: elapsedSeconds, day: day, hour: hour)
  }

  /// True once any answer has been given (closing then asks for confirmation).
  var hasProgress: Bool { !records.isEmpty }
}
