import Foundation
import Testing

@testable import MahjongCore

private let practice = Analyzer.cached(for: PracticeCard.card)

/// How many seeds each (type, difficulty) is checked with.
private let seedsPerCase = Int(ProcessInfo.processInfo.environment["EXERCISE_SEEDS"] ?? "") ?? 500

/// A short, stable description of everything a player can see, to compare two generations.
private func fingerprint(_ e: Exercise) -> String {
  "\(e.prompt)|\(e.tiles.map(\.code))|\(e.groups.map { $0.map(\.code) })|\(e.lines.map(\.id))|\(e.choices)|\(e.selectCount)|\(e.queue.map(\.code))|\(e.discard?.code ?? "-")"
}

/// An answer that is right for the exercise, found without going through the grader.
private func rightAnswer(_ e: Exercise) -> Answer {
  switch e.key {
  case .choices(let correct, _, _):
    return .choice(correct.sorted().first ?? 0)
  case .pickHand:
    let results = practice.analyze(PlayerView(rack: e.tiles))
    let distances = Dictionary(uniqueKeysWithValues: results.map { ($0.line.id, $0.best.distance) })
    var best = 0
    for (i, choice) in e.choices.enumerated() {
      guard case .line(let line) = choice, case .line(let current) = e.choices[best] else { continue }
      if distances[line.id, default: 99] < distances[current.id, default: 99] { best = i }
    }
    return .choice(best)
  case .passOne(let lineIndex):
    let evaluation = practice.evaluation(at: lineIndex, tiles: e.tiles)!
    let held = e.tiles.counts
    let position = e.tiles.indices.first { i in
      let t = e.tiles[i]
      return t != .joker && (held[t] ?? 0) > (evaluation.usedRack[t] ?? 0)
    }
    return .tiles([position ?? 0])
  case .passThree:
    var advice = practice.suggestPasses(PlayerView(rack: e.tiles), count: 3).passes.map(\.tile)
    var positions: [Int] = []
    for (i, t) in e.tiles.enumerated() {
      if let at = advice.firstIndex(of: t) {
        advice.remove(at: at)
        positions.append(i)
      }
    }
    return .tiles(positions)
  case .keepOrPass(let keeps, _):
    return .decisions(keeps)
  case .none:
    return .choice(0)
  }
}

private func wrongAnswer(_ e: Exercise) -> Answer? {
  switch e.key {
  case .choices(let correct, _, _):
    guard let i = e.choices.indices.first(where: { !correct.contains($0) }) else { return nil }
    return .choice(i)
  case .keepOrPass(let keeps, _):
    return .decisions(keeps.map { !$0 })
  default:
    return nil
  }
}

struct ExerciseGenerationTests {
  @Test(arguments: ExerciseType.allCases)
  func everyDifficultyIsGradableAndStable(type: ExerciseType) {
    for difficulty in 1...3 {
      var filtered = 0
      for n in 0..<seedsPerCase {
        let id = ExerciseID(type: type, seed: UInt64(1000 + n * 7), difficulty: difficulty)
        let (exercise, passed) = Exercises.makeWithStatus(id, analyzer: practice)
        if passed { filtered += 1 }
        #expect(!exercise.prompt.isEmpty, "\(id)")

        // Stable: the same ID builds the same question.
        if n % 10 == 0 {
          #expect(fingerprint(Exercises.make(id, analyzer: practice)) == fingerprint(exercise), "\(id)")
        }

        // Structure
        switch type {
        case .passOne, .passThree:
          #expect(exercise.tiles.count == 13)
          #expect(exercise.selectCount == (type == .passOne ? 1 : 3))
        case .keepOrPass:
          #expect(exercise.queue.count == 5)
          #expect(exercise.tiles.count == 13)
        default:
          #expect(exercise.choices.count >= 2, "\(id)")
        }
        #expect(exercise.tiles.filter { $0 == .blank }.isEmpty)

        // The right answer is graded right, with an explanation.
        let good = Exercises.grade(exercise, answer: rightAnswer(exercise), analyzer: practice)
        #expect(good.correct, "\(id) \(good.explanation)")
        #expect(!good.explanation.isEmpty, "\(id)")
        if let bad = wrongAnswer(exercise) {
          #expect(!Exercises.grade(exercise, answer: bad, analyzer: practice).correct, "\(id)")
        }
      }
      #expect(Double(filtered) >= 0.95 * Double(seedsPerCase), "\(type) d\(difficulty): \(filtered)/\(seedsPerCase)")
    }
  }
}
