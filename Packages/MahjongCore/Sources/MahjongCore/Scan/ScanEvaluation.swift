import Foundation

public enum ScanTruthKind: String, Codable, Sendable {
  /// A row a person can read from the source; a draft is expected to match its semantics.
  case readable
  /// A deliberately unreadable or ambiguous row; the scanner must flag or reject it, never call it ready.
  case ambiguous
}

public struct ScanTruthRow: Hashable, Codable, Sendable {
  public var id: String
  public var kind: ScanTruthKind
  /// The intended hand. For ambiguous rows this is only used to pair a candidate with the row.
  public var line: CardLine

  public init(id: String, kind: ScanTruthKind, line: CardLine) {
    self.id = id
    self.kind = kind
    self.line = line
  }
}

public enum ScanRowOutcome: String, Codable, Sendable {
  /// Readable row, draft semantically exact and ready.
  case exactReady
  /// Readable row, draft semantically exact but flagged for a check (no repair needed, user confirms).
  case exactFlagged
  /// Readable row, draft wrong or incomplete and correctly flagged.
  case needsCorrection
  /// Readable row, draft wrong but presented as ready. A gate failure.
  case readyButWrong
  /// Readable row with no draft at all.
  case omitted
  case ambiguousFlagged
  /// Ambiguous row with no draft (rejected).
  case ambiguousRejected
  /// Ambiguous row presented as ready. A gate failure.
  case ambiguousReady
}

/// Aggregate counts. Contains no row contents, so it is safe to commit for private samples.
public struct ScanTally: Hashable, Codable, Sendable {
  public var exactReady = 0
  public var exactFlagged = 0
  public var needsCorrection = 0
  public var readyButWrong = 0
  public var omitted = 0
  public var ambiguousFlagged = 0
  public var ambiguousRejected = 0
  public var ambiguousReady = 0
  /// Drafts that match no truth row and were presented as ready (counted as ready-but-wrong).
  public var spuriousReady = 0
  public var spuriousFlagged = 0

  public init() {}

  public var readableRows: Int {
    exactReady + exactFlagged + needsCorrection + readyButWrong + omitted
  }
  public var exactDrafts: Int { exactReady + exactFlagged }
  public var ambiguousRows: Int { ambiguousFlagged + ambiguousRejected + ambiguousReady }
  /// Every semantically wrong draft that was labelled ready, including spurious extra rows.
  public var readyButWrongTotal: Int { readyButWrong + spuriousReady }
  public var exactRate: Double { readableRows == 0 ? 0 : Double(exactDrafts) / Double(readableRows) }
  public var exactReadyRate: Double {
    readableRows == 0 ? 0 : Double(exactReady) / Double(readableRows)
  }

  public mutating func add(_ other: ScanTally) {
    exactReady += other.exactReady
    exactFlagged += other.exactFlagged
    needsCorrection += other.needsCorrection
    readyButWrong += other.readyButWrong
    omitted += other.omitted
    ambiguousFlagged += other.ambiguousFlagged
    ambiguousRejected += other.ambiguousRejected
    ambiguousReady += other.ambiguousReady
    spuriousReady += other.spuriousReady
    spuriousFlagged += other.spuriousFlagged
  }

  mutating func record(_ outcome: ScanRowOutcome) {
    switch outcome {
    case .exactReady: exactReady += 1
    case .exactFlagged: exactFlagged += 1
    case .needsCorrection: needsCorrection += 1
    case .readyButWrong: readyButWrong += 1
    case .omitted: omitted += 1
    case .ambiguousFlagged: ambiguousFlagged += 1
    case .ambiguousRejected: ambiguousRejected += 1
    case .ambiguousReady: ambiguousReady += 1
    }
  }
}

public struct ScanEvaluation: Hashable, Sendable {
  public var tally: ScanTally
  public var outcomes: [String: ScanRowOutcome]

  public init(tally: ScanTally, outcomes: [String: ScanRowOutcome]) {
    self.tally = tally
    self.outcomes = outcomes
  }
}

public enum ScanEvaluator {
  /// Minimum similarity for a wrong draft to be paired with a truth row it was probably meant for.
  public static let pairingThreshold = 0.45

  /// Compare a recognised draft with the annotated truth for one page set.
  ///
  /// Pairing is order-independent: exact semantic matches first, then the most similar remaining pairs.
  /// Semantic equality is the only thing that counts as correct. Text similarity is never credit.
  public static func evaluate(truth: [ScanTruthRow], candidates: [ScanCandidate]) -> ScanEvaluation {
    var pairing: [Int: Int] = [:]  // truth index -> candidate index
    var usedCandidates = Set<Int>()
    let truthKeys = truth.map { ScanSemantics.key($0.line) }

    for (t, row) in truth.enumerated() where row.kind == .readable {
      for (c, candidate) in candidates.enumerated()
      where !usedCandidates.contains(c) && candidate.semanticKey == truthKeys[t] {
        pairing[t] = c
        usedCandidates.insert(c)
        break
      }
    }

    var scored: [(score: Double, t: Int, c: Int)] = []
    for (t, row) in truth.enumerated() where pairing[t] == nil {
      for (c, candidate) in candidates.enumerated() where !usedCandidates.contains(c) {
        guard let line = candidate.line else { continue }
        let score = ScanSemantics.similarity(row.line, line)
        if score >= pairingThreshold { scored.append((score, t, c)) }
      }
    }
    scored.sort { $0.score > $1.score }
    for item in scored where pairing[item.t] == nil && !usedCandidates.contains(item.c) {
      pairing[item.t] = item.c
      usedCandidates.insert(item.c)
    }

    var tally = ScanTally()
    var outcomes: [String: ScanRowOutcome] = [:]
    for (t, row) in truth.enumerated() {
      let candidate = pairing[t].map { candidates[$0] }
      let outcome: ScanRowOutcome
      switch row.kind {
      case .readable:
        if let candidate {
          if candidate.semanticKey == truthKeys[t] {
            outcome = candidate.state == .ready ? .exactReady : .exactFlagged
          } else {
            outcome = candidate.state == .ready ? .readyButWrong : .needsCorrection
          }
        } else {
          outcome = .omitted
        }
      case .ambiguous:
        if let candidate {
          outcome = candidate.state == .ready ? .ambiguousReady : .ambiguousFlagged
        } else {
          outcome = .ambiguousRejected
        }
      }
      tally.record(outcome)
      outcomes[row.id] = outcome
    }
    for (c, candidate) in candidates.enumerated() where !usedCandidates.contains(c) {
      if candidate.state == .ready { tally.spuriousReady += 1 } else { tally.spuriousFlagged += 1 }
    }
    return ScanEvaluation(tally: tally, outcomes: outcomes)
  }
}

/// The beta gate from NEXT_WAVES_SPEC §4.1, applied to a tally.
public struct ScanGateVerdict: Hashable, Sendable {
  public var exactRate: Double
  public var exactRatePasses: Bool
  public var ambiguousAllFlagged: Bool
  public var zeroReadyButWrong: Bool

  public static let minimumExactRate = 0.60

  public init(_ tally: ScanTally) {
    exactRate = tally.exactRate
    exactRatePasses = tally.exactRate >= Self.minimumExactRate
    ambiguousAllFlagged = tally.ambiguousReady == 0
    zeroReadyButWrong = tally.readyButWrongTotal == 0
  }

  public var passes: Bool { exactRatePasses && ambiguousAllFlagged && zeroReadyButWrong }
}
