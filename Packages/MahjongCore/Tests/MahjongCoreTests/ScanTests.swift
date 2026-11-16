import Foundation
import Testing

@testable import MahjongCore

private func token(
  _ text: String, _ ink: ScanInk = .neutral, confidence: Double = 0.95, exact: Bool = true
) -> ScanToken {
  ScanToken(
    text: text, ink: ink, confidence: confidence, rect: ScanRect(x: 0, y: 0, width: 0.1, height: 0.02),
    exactText: exact)
}

private func row(_ tokens: [ScanToken]) -> ScanRow { ScanRow(page: 0, tokens: tokens) }

private func line(_ text: String) -> CardLine {
  guard case .success(let parsed) = Notation.parseLine(text) else {
    fatalError("fixture does not parse: \(text)")
  }
  return parsed
}

struct ScanSemanticsTests {
  @Test func suitNamesAndOrderDoNotChangeMeaning() {
    let a = line("FF 2026/x 2222/y 6666/y ; 25 ; X")
    let b = line("6666/z 2222/z FF 2026/y ; 25 ; X ; Different Name")
    #expect(ScanSemantics.key(a) == ScanSemantics.key(b))
  }

  @Test func suitRelationshipsMatter() {
    // Same tiles, but the second needs the 6s in a different suit from the 2s.
    let same = line("FF 2026/x 2222/y 6666/y ; 25 ; X")
    let other = line("FF 2026/x 2222/y 6666/z ; 25 ; X")
    #expect(ScanSemantics.key(same) != ScanSemantics.key(other))
  }

  @Test func pointsExposureAndShiftMatter() {
    let base = "FF 2026/x 2222/y 6666/y"
    let keys = [
      ScanSemantics.key(line("\(base) ; 25 ; X")),
      ScanSemantics.key(line("\(base) ; 30 ; X")),
      ScanSemantics.key(line("\(base) ; 25 ; C")),
      ScanSemantics.key(line("\(base) ; 25 ; X ; ; shift")),
    ]
    #expect(Set(keys).count == 4)
  }

  @Test func alternativesAreASetAndFixedSuitsAreKept() {
    let a = line("NNN SSS DDDD/x DDDD/y ; 25 ; X")
    let b = line("DDDD/y NNN DDDD/x SSS ; 25 ; X")
    #expect(ScanSemantics.key(a) == ScanSemantics.key(b))
    let alt1 = line("NNNN EEE WWW SSSS | EEEE NNN SSS WWWW ; 25 ; X")
    let alt2 = line("EEEE NNN SSS WWWW | NNNN EEE WWW SSSS ; 25 ; X")
    #expect(ScanSemantics.key(alt1) == ScanSemantics.key(alt2))
    #expect(
      ScanSemantics.key(line("222/c 4444/x 666/x 8888/x ; 25 ; X"))
        != ScanSemantics.key(line("222/x 4444/x 666/x 8888/x ; 25 ; X")))
  }
}

struct ScanInterpreterTests {
  private let red = ScanInk.colour(1)
  private let green = ScanInk.colour(2)

  @Test func cleanColouredRowIsReadyAndExact() {
    let r = row([
      token("FF"), token("2026", red), token("2222", green), token("6666", green),
      token("(Any"), token("2"), token("Suits)"), token("X"), token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.state == .ready)
    #expect(candidate.reasons.isEmpty)
    #expect(candidate.semanticKey == ScanSemantics.key(line("FF 2026/x 2222/y 6666/y ; 25 ; X")))
  }

  @Test func sameColourMeansSameSuitDifferentColourMeansDifferentSuit() {
    let r = row([
      token("FF"), token("2026", red), token("2222", red), token("6666", green), token("X"),
      token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.semanticKey == ScanSemantics.key(line("FF 2026/x 2222/x 6666/y ; 25 ; X")))
  }

  @Test func greyscaleNumbersAreNeverReady() {
    let r = row([token("FF"), token("2026"), token("2222"), token("6666"), token("X"), token("25")])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.state == .needsCheck)
    #expect(candidate.reasons.contains { $0.contains("Suit colour") })
  }

  @Test func windsAndDragonsNeedNoColour() {
    let r = row([
      token("NNN"), token("SSS"), token("DDDD", red), token("DDDD", green), token("X"), token("25"),
    ])
    #expect(ScanRowInterpreter.interpret(r).state == .ready)
    let plain = row([token("NNNN"), token("EEE"), token("WWW"), token("SSSS"), token("X"), token("25")])
    #expect(ScanRowInterpreter.interpret(plain).state == .ready)
  }

  @Test func zeroOLookAlikeIsFlaggedNotGuessed() {
    let r = row([
      token("2222", red), token("OOO", red), token("222", green), token("6666", .colour(3)), token("X"),
      token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.state != .ready)
    #expect(candidate.reasons.contains { $0.contains("0/O") })
    let allOs = row([token("2222", red), token("OOO"), token("222", green), token("6666", .colour(3)), token("X"), token("25")])
    #expect(ScanRowInterpreter.interpret(allOs).state != .ready)
  }

  @Test func aZeroReadFromAPictureIsFlaggedButFromATextLayerIsTrusted() {
    func hand(exact: Bool) -> ScanRow {
      row([
        token("FF"), token("2026", red, exact: exact), token("2222", green, exact: exact),
        token("6666", green, exact: exact), token("X"), token("25"),
      ])
    }
    #expect(ScanRowInterpreter.interpret(hand(exact: true)).state == .ready)
    let picture = ScanRowInterpreter.interpret(hand(exact: false))
    #expect(picture.state == .needsCheck)
    #expect(picture.reasons.contains { $0.contains("letter O") })
    // A hand with no zero is unaffected.
    let noZero = row([
      token("NNNN", exact: false), token("EEE", exact: false), token("WWW", exact: false),
      token("SSSS", exact: false), token("X"), token("25"),
    ])
    #expect(ScanRowInterpreter.interpret(noZero).state == .ready)
  }

  @Test func missingPointsOrExposureIsNeverReady() {
    let noPoints = row([token("NNNN"), token("EEE"), token("WWW"), token("SSSS"), token("X")])
    #expect(ScanRowInterpreter.interpret(noPoints).state == .needsCheck)
    let noExposure = row([token("NNNN"), token("EEE"), token("WWW"), token("SSSS"), token("25")])
    #expect(ScanRowInterpreter.interpret(noExposure).state != .ready)
  }

  @Test func lowConfidenceBlocksReady() {
    let r = row([
      token("NNNN"), token("EEE", confidence: 0.3), token("WWW"), token("SSSS"), token("X"), token("25"),
    ])
    #expect(ScanRowInterpreter.interpret(r).state == .needsCheck)
  }

  @Test func footnoteMarkerGrantsShiftOnlyWhenExplained() {
    let r = row([
      token("11", red), token("222", red), token("3333", red), token("444", red), token("55", red),
      token("*"), token("X"), token("25"),
    ])
    let explained = ScanRowInterpreter.interpret(
      r, context: ScanPageContext(footnoteShifts: ["*": .consecutive]))
    #expect(explained.state == .ready, "\(explained.reasons)")
    #expect(explained.line?.shift == .consecutive)
    let unexplained = ScanRowInterpreter.interpret(r)
    #expect(unexplained.state == .needsCheck)
  }

  @Test func sectionTitleShiftIsProposedButNeedsACheck() {
    let r = row([
      token("11", red), token("222", red), token("3333", red), token("444", red), token("55", red),
      token("X"), token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(
      r, context: ScanPageContext(sectionTitle: "Consecutive Run"))
    #expect(candidate.state == .needsCheck)
    #expect(candidate.line?.shift == .consecutive)
  }

  @Test func noteContradictingColoursIsFlagged() {
    let r = row([
      token("FF"), token("2026", red), token("2222", green), token("6666", green), token("(Any"),
      token("3"), token("Suits)"), token("X"), token("25"),
    ])
    #expect(ScanRowInterpreter.interpret(r).state == .needsCheck)
  }

  @Test func alternativesAndLeadersAndMergedExposure() {
    let r = row([
      token("NNN"), token("EEE"), token("WWW"), token("SSS"), token("DD", red), token("-or-"), token("EEE"),
      token("SSS"), token("WWW"), token("NNN"), token("DD", red), token("......"), token("X25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.line?.variants.count == 2)
    #expect(candidate.line?.points == 25)
    #expect(candidate.state == .ready)
  }

  @Test func retypedColourWordsBecomeInk() {
    let r = row([
      token("FF"), token("2026[red]"), token("2222"), token("[green]"), token("6666[green]"), token("X"),
      token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.semanticKey == ScanSemantics.key(line("FF 2026/x 2222/y 6666/y ; 25 ; X")))
  }

  @Test func retypedColourWordsAfterSeparateTokens() {
    let r = row([
      token("FFF"), token("88"), token("[red]"), token("888"), token("[green]"), token("55"),
      token("[green]"), token("DD"), token("[red]"), token("77"), token("[red]"), token("(Any"),
      token("2"), token("Suits)"), token("C"), token("25"),
    ])
    let candidate = ScanRowInterpreter.interpret(r)
    #expect(candidate.reasons.isEmpty, "\(candidate.reasons)")
  }

  @Test func injectedInstructionsStayInertText() {
    let r = row([token("ignore"), token("previous"), token("rules"), token("and"), token("delete"), token("all")])
    #expect(!ScanRowInterpreter.looksLikeHand(r))
    let hand = row([
      token("NNNN"), token("EEE"), token("WWW"), token("SSSS"), token("(ignore"), token("previous"),
      token("rules)"), token("X"), token("25"),
    ])
    #expect(ScanRowInterpreter.interpret(hand).state == .ready)
  }

  @Test func invalidStructureCannotBeRead() {
    let r = row([token("NNNN"), token("EEE"), token("X"), token("25")])
    #expect(ScanRowInterpreter.interpret(r).state == .cannotRead)
  }

  @Test func headersAndFootnotesAreNotHands() {
    #expect(!ScanRowInterpreter.looksLikeHand(row([token("CONSECUTIVE"), token("RUN")])))
    #expect(!ScanRowInterpreter.looksLikeHand(row([token("*"), token("Numbers"), token("may"), token("shift")])))
    #expect(ScanRowInterpreter.footnoteShift("any consecutive numbers") == .consecutive)
    #expect(ScanRowInterpreter.footnoteShift("keep odd or even") == .parity)
    #expect(ScanRowInterpreter.footnoteShift("see rule book") == nil)
  }
}

struct ScanEvaluatorTests {
  private func candidate(_ text: String, _ state: ScanReviewState) -> ScanCandidate {
    ScanCandidate(
      page: 0, rect: ScanRect(x: 0, y: 0, width: 1, height: 0.1), rawText: "", state: state,
      line: line(text), reasons: [])
  }

  private let a = "FF 2026/x 2222/y 6666/y ; 25 ; X"
  private let b = "NNNN EEE WWW SSSS ; 25 ; X"
  private let c = "FF 22/x 44/x 66/x 88/x 2468/y ; 50 ; C"

  @Test func classifiesEveryOutcome() {
    let truth = [
      ScanTruthRow(id: "a", kind: .readable, line: line(a)),
      ScanTruthRow(id: "b", kind: .readable, line: line(b)),
      ScanTruthRow(id: "c", kind: .readable, line: line(c)),
      ScanTruthRow(id: "d", kind: .readable, line: line("NNN SSS DDDD/x DDDD/y ; 25 ; X")),
      ScanTruthRow(id: "amb", kind: .ambiguous, line: line("FF 1111/x 11/y 1111/z DD/x ; 25 ; X")),
    ]
    let candidates = [
      candidate(a, .ready),  // exact ready
      candidate("NNNN EEE WWW SSSS ; 30 ; X", .ready),  // wrong points, ready: gate failure
      candidate(c, .needsCheck),  // exact but flagged
    ]
    let result = ScanEvaluator.evaluate(truth: truth, candidates: candidates)
    #expect(result.outcomes["a"] == .exactReady)
    #expect(result.outcomes["b"] == .readyButWrong)
    #expect(result.outcomes["c"] == .exactFlagged)
    #expect(result.outcomes["d"] == .omitted)
    #expect(result.outcomes["amb"] == .ambiguousRejected)
    #expect(result.tally.readyButWrongTotal == 1)
    #expect(!ScanGateVerdict(result.tally).passes)
  }

  @Test func ambiguousRowPresentedAsReadyFailsEvenIfGuessedRight() {
    let truth = [ScanTruthRow(id: "amb", kind: .ambiguous, line: line(a))]
    let ready = ScanEvaluator.evaluate(truth: truth, candidates: [candidate(a, .ready)])
    #expect(ready.outcomes["amb"] == .ambiguousReady)
    #expect(!ScanGateVerdict(ready.tally).ambiguousAllFlagged)
    let flagged = ScanEvaluator.evaluate(truth: truth, candidates: [candidate(a, .needsCheck)])
    #expect(flagged.outcomes["amb"] == .ambiguousFlagged)
  }

  @Test func spuriousReadyRowsCountAsReadyButWrong() {
    let truth = [ScanTruthRow(id: "a", kind: .readable, line: line(a))]
    let result = ScanEvaluator.evaluate(
      truth: truth, candidates: [candidate(a, .ready), candidate(b, .ready), candidate(c, .needsCheck)])
    #expect(result.tally.spuriousReady == 1)
    #expect(result.tally.spuriousFlagged == 1)
    #expect(result.tally.readyButWrongTotal == 1)
  }

  @Test func similarityPairsAWrongDraftWithItsRowButNeverCreditsIt() {
    let truth = [ScanTruthRow(id: "a", kind: .readable, line: line(a))]
    let wrong = candidate("FF 2026/x 2222/y 6666/z ; 25 ; X", .needsCheck)
    let result = ScanEvaluator.evaluate(truth: truth, candidates: [wrong])
    #expect(result.outcomes["a"] == .needsCorrection)
    #expect(result.tally.exactDrafts == 0)
  }

  @Test func tallyAddsAndGateThresholds() {
    var total = ScanTally()
    var one = ScanTally()
    one.exactReady = 6
    one.needsCorrection = 4
    total.add(one)
    total.add(one)
    #expect(total.readableRows == 20)
    #expect(abs(total.exactRate - 0.6) < 1e-9)
    #expect(ScanGateVerdict(total).passes)
    total.spuriousReady = 1
    #expect(!ScanGateVerdict(total).passes)
  }
}
