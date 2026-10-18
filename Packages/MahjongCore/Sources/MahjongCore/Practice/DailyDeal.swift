import Foundation

/// The Daily Deal (SPEC §18.8): one deal per calendar day, the same for everyone, with no server.
public enum DailyDeal {
  public static let epoch = LocalDay(year: 2026, month: 1, day: 1)

  /// "Daily #289": whole days since 2026-01-01.
  public static func number(for day: LocalDay) -> Int { day.days(since: epoch) }

  /// `SplitMix64(daysSince(2026-01-01) xor 0x4D4A)`.
  public static func seed(for day: LocalDay) -> UInt64 {
    var generator = SeededRandom(seed: UInt64(bitPattern: Int64(number(for: day))) ^ 0x4D4A)
    return generator.next()
  }

  /// 1 (Monday, easiest) ... 7 (Sunday, hardest).
  public static func difficulty(for day: LocalDay) -> Int { day.isoWeekday }

  public struct Deal: Sendable {
    public var day: LocalDay
    public var number: Int
    public var weekdayLevel: Int
    public var seed: UInt64
    public var hand: [Tile]
  }

  /// How many tiles clearer the best line is than the best line of any other section.
  static func gap(_ results: [LineResult]) -> Int {
    guard let best = results.first(where: { $0.best.possible }) else { return 0 }
    let others = results.filter { $0.best.possible && $0.line.section != best.line.section }
    guard let second = others.map(\.best.distance).min() else { return 9 }
    return second - best.best.distance
  }

  /// The day's 13 tiles. Monday to Wednesday are built around one hand so the best choice shows; Thursday
  /// to Sunday are random deals filtered from clear to murky.
  public static func deal(for day: LocalDay, analyzer: Analyzer) -> Deal {
    let level = difficulty(for: day)
    let base = seed(for: day)
    var generator = SeededRandom(seed: base)
    var last: (seed: UInt64, hand: [Tile])?
    for attempt in 0..<Exercises.maxAttempts {
      let candidate = attempt == 0 ? base : generator.next()
      var rng = SeededRandom(seed: candidate ^ 0xDA11)
      let hand: [Tile]
      switch level {
      case 1: hand = Exercises.stackedDeal(analyzer, rng: &rng, keep: 9)?.hand ?? Wall.deal(seed: candidate).hand.sortedForDisplay()
      case 2: hand = Exercises.stackedDeal(analyzer, rng: &rng, keep: 8)?.hand ?? Wall.deal(seed: candidate).hand.sortedForDisplay()
      case 3: hand = Exercises.stackedDeal(analyzer, rng: &rng, keep: 7)?.hand ?? Wall.deal(seed: candidate).hand.sortedForDisplay()
      default: hand = Wall.deal(seed: candidate).hand.sortedForDisplay()
      }
      last = (candidate, hand)
      let results = analyzer.analyze(PlayerView(rack: hand))
      guard let best = results.first(where: { $0.best.possible }) else { continue }
      let gap = gap(results)
      let passes: Bool
      switch level {
      case 1, 2: passes = gap >= 2
      case 3: passes = gap >= 1
      case 4: passes = gap >= 2
      case 5: passes = true
      case 6: passes = gap <= 1
      default: passes = gap <= 1 && best.best.distance >= 8
      }
      if passes { return Deal(day: day, number: number(for: day), weekdayLevel: level, seed: candidate, hand: hand) }
    }
    let fallback = last ?? (base, Wall.deal(seed: base).hand.sortedForDisplay())
    return Deal(day: day, number: number(for: day), weekdayLevel: level, seed: fallback.seed, hand: fallback.hand)
  }

  /// The two questions of the day, both about the same 13 tiles.
  public static func exercises(for day: LocalDay, analyzer: Analyzer) -> (pick: Exercise, pass: Exercise) {
    let deal = deal(for: day, analyzer: analyzer)
    let pickID = ExerciseID(type: .pickHand, seed: deal.seed, difficulty: 3)
    let passID = ExerciseID(type: .passThree, seed: deal.seed, difficulty: 3)
    let pick = Exercise(
      id: pickID, prompt: "Which hand would you aim for?", tiles: deal.hand,
      choices: analyzer.card.lines.map { .line($0) }, key: .pickHand(restricted: false))
    let pass = Exercise(id: passID, prompt: "Pass three tiles.", tiles: deal.hand, selectCount: 3, key: .passThree)
    return (pick, pass)
  }

  // MARK: Results

  public enum PickMark: String, Codable, Sendable { case best, good, miss }
  public enum PassMark: String, Codable, Sendable { case green, yellow, red }

  public struct Result: Sendable {
    public var pick: PickMark
    public var pickDistance: Int
    public var pass: [PassMark]
  }

  /// Marks the pick and the three passed tiles (positions in `deal.hand`).
  public static func result(
    hand: [Tile], pickedLine: CardLine, passSelection: [Int], analyzer: Analyzer
  ) -> Result {
    let results = analyzer.analyze(PlayerView(rack: hand))
    let bestDistance = results.first { $0.best.possible }?.best.distance ?? 0
    let picked = results.first { $0.line.id == pickedLine.id }
    let pickedDistance = picked?.best.distance ?? 0
    let graded = PickScorer.grade(hand: hand, picked: pickedLine, offered: nil, analyzer: analyzer)
    let pickMark: PickMark = graded?.correct == true ? (pickedDistance <= bestDistance ? .best : .good) : .miss

    let top = PassTop(results: results)
    let threshold = top.threshold(hand: hand) ?? 0
    let held = hand.counts
    var taken: [Tile: Int] = [:]
    var marks: [PassMark] = []
    for position in passSelection where hand.indices.contains(position) {
      let tile = hand[position]
      let used = taken[tile, default: 0]
      taken[tile] = used + 1
      let instance = max(0, (held[tile] ?? 1) - 1 - used)
      let utility = top.utility(of: tile, instance: instance)
      if utility <= threshold + PassTop.tolerance {
        marks.append(.green)
      } else if utility >= 1.0 - PassTop.tolerance {
        marks.append(.red)
      } else {
        marks.append(.yellow)
      }
    }
    return Result(pick: pickMark, pickDistance: pickedDistance, pass: marks)
  }

  /// The text people share (SPEC §18.8).
  public static func shareText(number: Int, result: Result, streak: Int) -> String {
    let pick: String
    switch result.pick {
    case .best: pick = "✅ (best hand, \(result.pickDistance) away)"
    case .good: pick = "✅ (good hand, \(result.pickDistance) away)"
    case .miss: pick = "❌ (\(result.pickDistance) away)"
    }
    let pass = result.pass.map { mark -> String in
      switch mark {
      case .green: return "🟩"
      case .yellow: return "🟨"
      case .red: return "🟥"
      }
    }.joined()
    var lines = ["Mahjong Mania Daily #\(number) 🀄", "Pick: \(pick)", "Pass: \(pass)"]
    if streak > 0 { lines.append("🔥 \(streak)-day streak") }
    return lines.joined(separator: "\n")
  }
}
