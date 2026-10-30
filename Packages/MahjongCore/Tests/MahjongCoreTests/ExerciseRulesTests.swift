import Foundation
import Testing

@testable import MahjongCore

private let practice = Analyzer.cached(for: PracticeCard.card)
private let seeds = Array(stride(from: UInt64(3), to: 3 + 7 * 60, by: 7))

private func make(_ type: ExerciseType, _ seed: UInt64, _ difficulty: Int, focus: Int = 0) -> Exercise {
  Exercises.make(ExerciseID(type: type, seed: seed, difficulty: difficulty, focus: focus), analyzer: practice)
}

struct ExerciseIDTests {
  @Test func codableRoundTripAndOldIDsWithoutFocus() throws {
    let id = ExerciseID(type: .howFar, seed: 99, difficulty: 2, focus: 0)
    let data = try JSONEncoder().encode(id)
    #expect(try JSONDecoder().decode(ExerciseID.self, from: data) == id)
    let old = Data(#"{"type":"passThree","seed":5,"difficulty":3}"#.utf8)
    #expect(try JSONDecoder().decode(ExerciseID.self, from: old).focus == 0)
    #expect(ExerciseID(type: .tileFact, seed: 1, difficulty: 9).difficulty == 3)
    #expect(ExerciseID(type: .tileFact, seed: 1, difficulty: -1).difficulty == 1)
  }

  @Test func sameIDSameQuestionDifferentSeedDifferentQuestion() {
    let a = make(.whichHand, 5, 2)
    let b = make(.whichHand, 5, 2)
    #expect(a.tiles == b.tiles && a.choices == b.choices)
    let others = (6...20).map { make(.whichHand, UInt64($0), 2).tiles }
    #expect(others.contains { $0 != a.tiles })
  }
}

struct TileExerciseTests {
  @Test func tileFactsStayInTheirFocusAndHaveFourDistinctChoices() {
    for difficulty in 1...3 {
      for focus in [0, ExerciseFocus.suitsAndDragons, ExerciseFocus.flowersJokersSoap] {
        for seed in seeds {
          let e = make(.tileFact, seed, difficulty, focus: focus)
          #expect(Set(e.choices).count == e.choices.count)
          let yesNo = e.choices.allSatisfy { if case .yesNo = $0 { return true } else { return false } }
          #expect(e.choices.count == (yesNo ? 2 : 4))
          #expect(e.tiles.isEmpty && !e.prompt.isEmpty)
          if case .choices(let correct, _, _) = e.key { #expect(correct.count == 1) }
          if difficulty == 1 {
            let facts = TileFacts.pool(difficulty: 1, focus: focus)
            #expect(!facts.contains(.nickname(.bams)) && !facts.contains(.dealer))
          }
        }
      }
    }
  }

  @Test func oldNameTileAndFindTileDecodeAsTileFacts() throws {
    for raw in ["nameTile", "findTile"] {
      let data = Data(#"{"type":"\#(raw)","seed":5,"difficulty":1,"focus":3}"#.utf8)
      #expect(try JSONDecoder().decode(ExerciseID.self, from: data).type == .tileFact)
    }
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(ExerciseID.self, from: Data(#"{"type":"bogus","seed":5,"difficulty":1}"#.utf8))
    }
  }

  @Test func lessonsDoNotRepeatATileFact() {
    for node in Curriculum.allNodes where node.kind == .lesson {
      for part in node.parts where part.types == [.tileFact] {
        let ids = Curriculum.exercises(for: node, seed: 77)
        let facts = ids.map { TileFacts.factIndex(seed: $0.seed, difficulty: $0.difficulty, focus: $0.focus) }
        #expect(Set(facts).count == facts.count, "\(node.id) repeats a fact")
      }
    }
  }

  @Test func houseRuleFactsOnlyAppearForTheRulesThatAreOn() {
    var blankRule = RuleSet(id: "x", name: "x")
    #expect(!TileFacts.houseFacts(blankRule).contains(.blankSwap), "blanks are off by default")
    if let i = blankRule.rules.firstIndex(where: { $0.id == RuleID.blanks }) {
      blankRule.rules[i].isEnabled = true
      blankRule.rules[i].blanks = BlankOptions(count: 4)
    }
    #expect(TileFacts.houseFacts(blankRule).contains(.blankSet))
    #expect(TileFacts.houseFacts(nil).isEmpty)
    var sawWhole = false
    for seed in UInt64(0)..<200 {
      let e = Exercises.make(
        ExerciseID(type: .tileFact, seed: seed, difficulty: 3), analyzer: practice, rules: blankRule)
      if e.prompt.contains("blanks, how many") {
        sawWhole = true
        if case .choices(_, let answer, _) = e.key { #expect(answer == "156") }
      }
    }
    #expect(sawWhole)
    // Without a rule book nothing mentions "your".
    for seed in UInt64(0)..<200 {
      let e = Exercises.make(ExerciseID(type: .tileFact, seed: seed, difficulty: 3), analyzer: practice)
      #expect(!e.prompt.lowercased().contains("your table"))
    }
  }

  @Test func groupNameAnswerIsNotInTheOrderOfTheCount() {
    // In order, "the third choice for three tiles" would answer it without knowing any names.
    var positional = 0
    var total = 0
    for seed in seeds {
      let e = make(.groupName, seed, 1)
      guard case .choices(let correct, _, _) = e.key else { continue }
      total += 1
      if correct == [e.tiles.count - 1] { positional += 1 }
    }
    #expect(positional < total * 2 / 3, "choices must be shuffled")
  }

  @Test func groupNameMatchesSizeAndJokersStayOutOfSinglesAndPairs() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.groupName, seed, difficulty)
        guard case .choices(let correct, let name, _) = e.key else { continue }
        #expect(name == groupNoun(e.tiles.count))
        #expect(correct.count == 1 && e.choices.indices.contains(correct.first ?? -1))
        if e.tiles.count <= 2 { #expect(!e.tiles.contains(.joker)) }
        if difficulty == 1 { #expect(e.choices.count == 4 && !e.tiles.contains(.joker)) }
      }
    }
  }
}

struct CardReadingTests {
  private func lineIndex(_ e: Exercise) -> Int { practice.lineIndex(of: e.line!)! }

  @Test func matchesLineAnswerIsTheEngineVerdict() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.matchesLine, seed, difficulty)
        #expect(e.tiles.count == 14)
        let truth = practice.matches(at: lineIndex(e), tiles: e.tiles)
        if case .choices(let correct, _, _) = e.key { #expect(correct == [truth ? 0 : 1]) }
      }
    }
  }

  @Test func exposedConcealedFocusAsksAboutCalling() {
    var asked = 0
    for seed in seeds {
      let e = make(.matchesLine, seed, 1, focus: ExerciseFocus.exposedConcealed)
      guard e.tiles.isEmpty, case .choices(let correct, _, _) = e.key else { continue }
      asked += 1
      #expect(correct == [e.line!.concealed ? 1 : 0])
    }
    #expect(asked > 10)
  }

  @Test func coloursFocusUsesLinesWithTwoSuits() {
    for seed in seeds {
      let e = make(.matchesLine, seed, 1, focus: ExerciseFocus.colours)
      let groups = e.line!.variants[0].groups
      #expect(Instantiate.variables(in: groups).count >= 2)
    }
  }

  @Test func whichHandHasExactlyOneMatchingChoice() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.whichHand, seed, difficulty)
        #expect(e.choices.count == difficulty + 1)
        let matching = e.choices.filter {
          guard case .line(let line) = $0 else { return false }
          return practice.matches(at: practice.lineIndex(of: line)!, tiles: e.tiles)
        }
        #expect(matching.count == 1)
        if difficulty == 1 { #expect(!e.tiles.contains(.joker)) }
        if difficulty == 3 { #expect(e.tiles.contains(.joker)) }
      }
    }
  }

  @Test func jokerLegalIsNoExactlyWhenAJokerSitsInASingleOrPair() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.jokerLegal, seed, difficulty)
        #expect(e.groups.flatMap { $0 } == e.tiles)
        let jokerInSmall = e.groups.contains { $0.count <= 2 && $0.contains(.joker) }
        if case .choices(let correct, _, _) = e.key { #expect(correct == [jokerInSmall ? 1 : 0]) }
        #expect(e.tiles.contains(.joker))
      }
    }
  }
}

struct DistanceTests {
  @Test func howFarIsTheEngineDistanceWithinTheDifficultyRange() {
    let ranges = [1: 1...3, 2: 2...5, 3: 3...6]
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.howFar, seed, difficulty)
        #expect(e.tiles.count == 13)
        let truth = practice.distance(at: practice.lineIndex(of: e.line!)!, tiles: e.tiles)!
        guard case .choices(let correct, _, _) = e.key, case .number(let shown) = e.choices[correct.first!] else {
          Issue.record("no key")
          continue
        }
        #expect(shown == truth)
        #expect(e.choices.count == 4 && Set(e.choices).count == 4)
        #expect(ranges[difficulty]!.contains(truth) || seed > 100)
      }
    }
  }

  @Test func neededTileHasExactlyOneHelpfulChoice() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.neededTile, seed, difficulty)
        let index = practice.lineIndex(of: e.line!)!
        let base = practice.distance(at: index, tiles: e.tiles)!
        let helpful = e.choices.filter {
          guard case .tile(let tile) = $0 else { return false }
          return practice.distance(at: index, tiles: e.tiles + [tile])! < base
        }
        #expect(helpful.count == 1)
      }
    }
  }
}

struct ChoosingTests {
  @Test func pickHandHardDealsAreTheV1DrillDeals() {
    for seed in seeds {
      let e = make(.pickHand, seed, 3)
      #expect(e.tiles == Wall.deal(seed: seed).hand.sortedForDisplay())
      #expect(e.choices.count == PracticeCard.card.lines.count)
    }
  }

  @Test func passThreeHardDealsAreTheV1DrillDeals() {
    for seed in seeds {
      #expect(make(.passThree, seed, 2).tiles.count == 13)
      #expect(make(.passThree, seed, 3).tiles.count == 13)
    }
  }

  @Test func pickHandEasyHasAClearBestSection() {
    for seed in seeds {
      let e = make(.pickHand, seed, 1)
      #expect(e.choices.count == 3)
      let results = practice.analyze(PlayerView(rack: e.tiles))
      let best = results.first!
      for other in results.dropFirst() where other.line.section != best.line.section && other.best.possible {
        #expect(other.best.distance >= best.best.distance + 2)
      }
    }
  }

  @Test func pickHandNormalOffersFiveAndExactlyOneIsClosest() {
    for seed in seeds {
      let e = make(.pickHand, seed, 2)
      #expect(e.choices.count == 5)
      let results = practice.analyze(PlayerView(rack: e.tiles))
      let distance = Dictionary(uniqueKeysWithValues: results.map { ($0.line.id, $0.best.distance) })
      let offered = e.choices.compactMap { c -> Int? in
        if case .line(let line) = c { return distance[line.id] }
        return nil
      }
      #expect(offered.filter { $0 == offered.min() }.count == 1)
    }
  }

  @Test func passOneSpareTilesFollowTheDifficulty() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.passOne, seed, difficulty)
        let index = practice.lineIndex(of: e.line!)!
        let ev = practice.evaluation(at: index, tiles: e.tiles)!
        let spare = ev.unusedRack.filter { $0 != .joker }.count
        if difficulty == 1 { #expect(spare >= 3) }
        if difficulty == 2 { #expect(spare == 2) }
        if difficulty == 3 { #expect(spare == 1) }
        #expect(!e.canSelect(position: e.tiles.firstIndex(of: .joker) ?? 99))
      }
    }
  }

  @Test func passingAJokerIsNeverRight() {
    for seed in seeds {
      var e = make(.passOne, seed, 3)
      guard let joker = e.tiles.firstIndex(of: .joker) else { continue }
      #expect(!Exercises.grade(e, answer: .tiles([joker]), analyzer: practice).correct)
      e = make(.passThree, seed, 2)
      guard let j = e.tiles.firstIndex(of: .joker) else { continue }
      let others = e.tiles.indices.filter { $0 != j }.prefix(2)
      #expect(!Exercises.grade(e, answer: .tiles([j] + others), analyzer: practice).correct)
    }
  }

  @Test func passThreeNeedsExactlyThreeAndGivesPartialCredit() {
    let e = make(.passThree, 12, 1)
    #expect(!Exercises.grade(e, answer: .tiles([0, 1]), analyzer: practice).correct)
    #expect(!Exercises.grade(e, answer: .tiles([0, 0, 1]), analyzer: practice).correct)
    let g = Exercises.grade(e, answer: .tiles([0, 1, 2]), analyzer: practice)
    #expect(g.outOf == 3 && (0...3).contains(g.score) && g.correct == (g.score == 3))
  }

  @Test func passThreeEasyShowsTwoLinesAndOthersNone() {
    for seed in seeds {
      #expect(make(.passThree, seed, 1).lines.count == 2)
      #expect(make(.passThree, seed, 2).lines.isEmpty)
    }
  }

  @Test func keepOrPassDecidesFiveTilesOfTheTargetHand() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.keepOrPass, seed, difficulty)
        let ev = practice.evaluation(at: practice.lineIndex(of: e.line!)!, tiles: e.tiles)!
        guard case .keepOrPass(let keeps, _) = e.key else { continue }
        for (tile, keep) in zip(e.queue, keeps) { #expect(keep == ((ev.usedRack[tile] ?? 0) > 0)) }
        #expect(Set(e.queue).count == 5)
        #expect(keeps.contains(true) && keeps.contains(false))
        let partial = Exercises.grade(e, answer: .decisions(keeps.enumerated().map { $0.offset == 0 ? !$0.element : $0.element }), analyzer: practice)
        #expect(!partial.correct && partial.score == 4 && partial.outOf == 5)
      }
    }
  }

  @Test func callItAnswerIsTheEnginesCallVerdict() {
    for difficulty in 1...3 {
      for seed in seeds {
        let e = make(.callIt, seed, difficulty)
        let verdicts = practice.checkCall(PlayerView(rack: e.tiles), tile: e.discard!)
        let calls = verdicts.contains {
          switch $0 {
          case .mahjong(let l), .expose(let l, _, _): return l.id == e.line!.id
          }
        }
        if case .choices(let correct, _, _) = e.key { #expect(correct == [calls ? 0 : 1]) }
      }
    }
  }
}

struct HintTests {
  @Test func hintsNeverRemoveTheRightAnswer() {
    for type in ExerciseType.allCases {
      for difficulty in 1...3 {
        for seed in seeds.prefix(15) {
          let e = make(type, seed, difficulty)
          let hint = Exercises.hint(for: e, analyzer: practice)
          if case .choices(let correct, _, _) = e.key {
            #expect(Set(hint.removeChoices).isDisjoint(with: correct), "\(type)")
            if e.choices.count > 2 { #expect(!hint.removeChoices.isEmpty, "\(type)") }
          }
          if case .pickHand = e.key {
            let right = Exercises.grade(e, answer: rightPick(e), analyzer: practice)
            #expect(right.correct)
          }
          #expect(!hint.text.isEmpty || type == .pickHand || type == .passOne, "\(type)")
        }
      }
    }
  }

  private func rightPick(_ e: Exercise) -> Answer {
    for i in e.choices.indices where Exercises.grade(e, answer: .choice(i), analyzer: practice).correct {
      return .choice(i)
    }
    return .choice(0)
  }

  @Test func passThreeHintShowsTwoLines() {
    #expect(Exercises.hint(for: make(.passThree, 4, 2), analyzer: practice).lines.count == 2)
  }
}

// MARK: Nothing is answered by what is printed on the screen (SPEC §19.1)

struct NotAnswerableFromTheScreenTests {
  private func text(of choice: Choice) -> String? {
    switch choice {
    case .text(let value): return value
    case .tile(let tile): return tile.name
    case .line(let line): return line.displayName
    case .number, .yesNo: return nil
    }
  }

  private func words(_ string: String) -> String {
    " " + string.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ") + " "
  }

  /// Everything readable on the question screen apart from the choices themselves.
  private func visibleText(_ e: Exercise) -> String {
    var parts = [e.prompt, e.caption ?? ""]
    parts += e.tiles.map(\.name) + e.queue.map(\.name) + (e.discard.map { [$0.name] } ?? [])
    return words(parts.joined(separator: " "))
  }

  @Test func theRightChoiceIsNeverPrintedOnTheQuestion() {
    for type in ExerciseType.allCases {
      for difficulty in 1...3 {
        for focus in 0...2 {
          for seed in seeds.prefix(25) {
            let e = make(type, seed, difficulty, focus: focus)
            guard case .choices(let correct, _, _) = e.key, let index = correct.first,
              e.choices.indices.contains(index), let right = text(of: e.choices[index])
            else { continue }
            let shown = visibleText(e)
            // Tile choices (neededTile) are allowed to be in the rack; text and lines are not.
            if case .tile = e.choices[index], type != .tileFact { continue }
            if type == .whichHand || type == .matchesLine { continue }
            #expect(!shown.contains(words(right)), "\(type) d\(difficulty) f\(focus) seed \(seed): \"\(e.prompt)\" shows \"\(right)\"")
          }
        }
      }
    }
  }

  @Test func numberAnswersAreNeverInThePrompt() {
    for type in ExerciseType.allCases {
      for difficulty in 1...3 {
        for seed in seeds.prefix(25) {
          let e = make(type, seed, difficulty)
          guard case .choices(let correct, _, _) = e.key, let index = correct.first,
            e.choices.indices.contains(index), case .number(let n) = e.choices[index]
          else { continue }
          #expect(!words(e.prompt).contains(words("\(n)")), "\(type): \"\(e.prompt)\"")
        }
      }
    }
  }

  @Test func theLessonsOfUnitOneNeverShowTilesOrLabels() {
    for node in Curriculum.lessons(inUnit: 1) {
      for id in Curriculum.exercises(for: node, seed: 5) {
        let e = Exercises.make(id, analyzer: practice)
        #expect(e.tiles.isEmpty && e.groups.isEmpty && e.queue.isEmpty, "\(node.id): nothing to read the answer from")
      }
    }
  }

  @Test func nameTheTileAndFindTheTileAreGone() {
    #expect(!ExerciseType.allCases.map(\.rawValue).contains("nameTile"))
    #expect(!ExerciseType.allCases.map(\.rawValue).contains("findTile"))
    let types = Set(Curriculum.allNodes.flatMap(\.parts).flatMap(\.types))
    #expect(types.isSubset(of: Set(ExerciseType.allCases)))
  }
}
