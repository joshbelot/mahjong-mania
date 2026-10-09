import Foundation
import MahjongCore

/// Destinations pushed on the Game tab's navigation stack.
enum GameRoute: Hashable {
  case newGame
  case session(String)
  case history
  case players
  case player(String)
}

// MARK: - Payment explanation (SPEC §11.7)

/// The plain-English line under the payment preview. Off/Peek get one line, Coach gets full sentences.
enum PaymentExplanation {
  /// "double", "the base", ... for a payment multiplier.
  static func word(_ multiplier: Int) -> String {
    switch multiplier {
    case 1: return "the base"
    case 2: return "double"
    case 3: return "triple"
    case 4: return "quadruple"
    default: return "\u{00D7}\(multiplier)"
    }
  }

  /// True when the jokerless multiplier really applies to this hand under these rules.
  static func jokerlessApplies(_ input: MahjongInput, rules: RuleSet) -> Bool {
    input.jokerless && (input.lineHasNoJokerGroups ? rules.jokerlessBonusForNoJokerLines : true)
  }

  static func text(
    input: MahjongInput, seats: [String], payments: [String: Int], rules: RuleSet,
    names: [String: String], coach: Bool
  ) -> String {
    let winnerName = names[input.winnerID] ?? "Winner"
    let collected = payments[input.winnerID] ?? 0
    let bonus = jokerlessApplies(input, rules: rules)

    var thrower: String?
    if let id = input.discarderID, id != input.winnerID, seats.contains(id) { thrower = id }
    let others = seats.filter { $0 != input.winnerID && $0 != thrower }
    let othersPay = others.first.map { -(payments[$0] ?? 0) } ?? 0

    if let thrower {
      let throwerName = names[thrower] ?? "Thrower"
      let throwerPays = -(payments[thrower] ?? 0)
      if !coach {
        var line = "\(throwerName) pays \(throwerPays) (threw it) \u{00B7} others pay \(othersPay)"
        if bonus { line += " \u{00B7} jokerless \u{00D7}\(rules.jokerlessMultiplier)" }
        return line
      }
      var parts = ["Base \(input.basePoints)."]
      if bonus {
        parts.append("Jokerless, so every payment is multiplied by \(rules.jokerlessMultiplier).")
      }
      parts.append(
        "\(throwerName) threw the winning tile, so \(throwerName) pays \(word(rules.discarderMultiplier)) (\(throwerPays))."
      )
      parts.append("Everyone else pays \(word(rules.othersOnDiscardMultiplier)) (\(othersPay)).")
      parts.append("\(winnerName) collects \(collected).")
      return parts.joined(separator: " ")
    }

    if !coach {
      var line = "Others pay \(othersPay) (self-pick)"
      if bonus { line += " \u{00B7} jokerless \u{00D7}\(rules.jokerlessMultiplier)" }
      return line
    }
    var parts = ["Base \(input.basePoints)."]
    if bonus {
      parts.append("Jokerless, so every payment is multiplied by \(rules.jokerlessMultiplier).")
    }
    parts.append(
      "\(winnerName) drew the winning tile, so everyone else pays \(word(rules.selfPickMultiplier)) (\(othersPay))."
    )
    parts.append("\(winnerName) collects \(collected).")
    return parts.joined(separator: " ")
  }
}

// MARK: - Record hand draft

/// The form state of the record-hand screen, with all of its rules (validation, line selection, jokerless).
struct RecordHandDraft: Equatable {
  enum How: Equatable { case selfPick, discard }

  static let quickPoints = [25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75]
  static let pointsRange = 0...500
  static let jokerlessNote = "Singles & Pairs hands are already jokerless \u{2014} no bonus"

  var winnerID: String?
  var how: How?
  var discarderID: String?
  var points = 0
  var cardID: String?
  var lineID: String?
  var lineLabel: String?
  /// The card's own points for the chosen line, used to show "custom value" when `points` differs.
  var linePoints: Int?
  var lineHasNoJokerGroups = false
  var jokerless = false
  var note = ""

  init() {}

  /// A draft pre-filled from a saved hand (edit mode). `card` supplies the line's points when available.
  init(editing input: MahjongInput, card: Card?) {
    winnerID = input.winnerID
    if let thrower = input.discarderID, thrower != input.winnerID {
      how = .discard
      discarderID = thrower
    } else {
      how = .selfPick
    }
    points = input.basePoints
    cardID = input.cardID
    lineID = input.lineID
    lineLabel = input.lineLabel
    lineHasNoJokerGroups = input.lineHasNoJokerGroups
    jokerless = input.jokerless
    note = input.note ?? ""
    if let lineID, let line = card?.lines.first(where: { $0.id == lineID }) {
      linePoints = line.points
    } else if lineID != nil || lineLabel != nil {
      linePoints = input.basePoints
    }
  }

  var hasLine: Bool { lineID != nil || lineLabel != nil }

  /// The line was chosen from a card but the points were changed afterwards.
  var isCustomValue: Bool { hasLine && linePoints != nil && linePoints != points }

  mutating func selectWinner(_ id: String) {
    winnerID = id
    if discarderID == id { discarderID = nil }
  }

  mutating func selectHow(_ value: How) {
    how = value
    if value == .selfPick { discarderID = nil }
  }

  mutating func apply(line: CardLine, cardID: String) {
    self.cardID = cardID
    lineID = line.id
    lineLabel = line.displayName
    linePoints = line.points
    points = line.points
    lineHasNoJokerGroups = line.hasNoJokerGroups
  }

  mutating func clearLine() {
    cardID = nil
    lineID = nil
    lineLabel = nil
    linePoints = nil
    lineHasNoJokerGroups = false
  }

  /// False when the chosen line has no joker groups and the rules give no bonus for that.
  func jokerlessEnabled(rules: RuleSet) -> Bool {
    !(lineHasNoJokerGroups && !rules.jokerlessBonusForNoJokerLines)
  }

  var isValid: Bool {
    guard winnerID != nil, points > 0, let how else { return false }
    if how == .discard { return discarderID != nil && discarderID != winnerID }
    return true
  }

  /// The hand to save, or nil while the form is incomplete.
  func input(rules: RuleSet) -> MahjongInput? {
    guard isValid, let winnerID, let how else { return nil }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    return MahjongInput(
      winnerID: winnerID, discarderID: how == .discard ? discarderID : nil, cardID: cardID,
      lineID: lineID, lineLabel: lineLabel, basePoints: points,
      jokerless: jokerless && jokerlessEnabled(rules: rules),
      lineHasNoJokerGroups: lineHasNoJokerGroups, note: trimmed.isEmpty ? nil : trimmed)
  }
}

// MARK: - Hand log text

enum HandLogText {
  struct Entry: Equatable {
    var title: String
    var meta: String
    /// Points shown on the right (winner's collection, or the adjustment size).
    var points: Int?
  }

  static func entry(for hand: HandRecord, rules: RuleSet, names: [String: String]) -> Entry {
    func name(_ id: String) -> String { names[id] ?? "Player" }
    switch hand.kind {
    case .mahjong(let input):
      let label = input.lineLabel ?? "\(input.basePoints) pts"
      var meta: [String] = []
      if let thrower = input.discarderID, thrower != input.winnerID {
        meta.append("from \(name(thrower))")
      } else {
        meta.append("self-pick")
      }
      if PaymentExplanation.jokerlessApplies(input, rules: rules) { meta.append("jokerless") }
      if let note = input.note, !note.isEmpty { meta.append(note) }
      return Entry(
        title: "\(name(input.winnerID)) \u{2014} \(label)",
        meta: meta.joined(separator: " \u{00B7} "), points: hand.payments[input.winnerID])
    case .wall:
      return Entry(title: "Wall game", meta: "No payments \u{00B7} the deal passes", points: nil)
    case .adjustment(let from, let to, let points, let note):
      var meta = "\(name(from)) \u{2192} \(name(to))"
      if let note, !note.isEmpty { meta += " \u{00B7} \(note)" }
      return Entry(title: "Adjustment", meta: meta, points: points)
    }
  }
}

// MARK: - Rules summary

enum RulesSummary {
  /// "Discarder ×2 · Self-pick ×2 · Jokerless ×2", plus anything that differs from the usual.
  static func text(_ rules: RuleSet) -> String {
    var parts = [
      "Discarder \u{00D7}\(rules.discarderMultiplier)",
      "Self-pick \u{00D7}\(rules.selfPickMultiplier)",
      "Jokerless \u{00D7}\(rules.jokerlessMultiplier)",
    ]
    if rules.othersOnDiscardMultiplier != 1 {
      parts.append("Others \u{00D7}\(rules.othersOnDiscardMultiplier)")
    }
    if rules.jokerlessBonusForNoJokerLines { parts.append("Bonus on Singles & Pairs") }
    return parts.joined(separator: " \u{00B7} ")
  }

  /// True when every payout rule equals the standard one (name, id and money are ignored).
  static func matchesStandard(_ rules: RuleSet) -> Bool {
    let standard = RuleSet.standard
    return rules.discarderMultiplier == standard.discarderMultiplier
      && rules.othersOnDiscardMultiplier == standard.othersOnDiscardMultiplier
      && rules.selfPickMultiplier == standard.selfPickMultiplier
      && rules.jokerlessMultiplier == standard.jokerlessMultiplier
      && rules.jokerlessBonusForNoJokerLines == standard.jokerlessBonusForNoJokerLines
  }

  /// "Standard rules", or the ruleset's own name, or "Custom rules" when a standard set was edited.
  static func title(_ rules: RuleSet) -> String {
    if rules.id == RuleSet.standard.id && !matchesStandard(rules) { return "Custom rules" }
    if matchesStandard(rules) && rules.name == RuleSet.standard.name { return "Standard rules" }
    return rules.name
  }
}

// MARK: - Summary

struct SummaryModel {
  struct Standing: Identifiable, Equatable {
    let id: String
    let points: Int
    let cents: Int
    let rank: Int
  }

  struct Highlight: Identifiable, Equatable {
    let title: String
    let value: String
    var id: String { title }
  }

  let session: Session
  let standings: [Standing]
  /// Empty when money is off.
  let transfers: [Transfer]

  init(session: Session) {
    self.session = session
    let totals = Scoring.totals(session)
    let cents = Scoring.moneyTotals(session)
    let seats = session.seatIDs
    let ordered = seats.sorted { a, b in
      let pa = totals[a] ?? 0
      let pb = totals[b] ?? 0
      if pa != pb { return pa > pb }
      return (seats.firstIndex(of: a) ?? 0) < (seats.firstIndex(of: b) ?? 0)
    }
    var result: [Standing] = []
    for (index, id) in ordered.enumerated() {
      let points = totals[id] ?? 0
      var rank = index + 1
      if let previous = result.last, previous.points == points { rank = previous.rank }
      result.append(Standing(id: id, points: points, cents: cents[id] ?? 0, rank: rank))
    }
    standings = result
    transfers = session.rules.money.enabled ? Scoring.settleUp(cents) : []
  }

  /// Players tied for first place (empty when nobody is ahead of zero).
  var leaderIDs: [String] {
    guard let top = standings.first?.points, top > 0 else { return [] }
    return standings.filter { $0.points == top }.map(\.id)
  }

  func highlights(names: [String: String]) -> [Highlight] {
    func name(_ id: String) -> String { names[id] ?? "Player" }
    var result: [Highlight] = []

    var biggest: (id: String, collected: Int, label: String)?
    var wins: [String: Int] = [:]
    var jokerlessWins: [String: Int] = [:]
    for hand in session.hands {
      guard case .mahjong(let input) = hand.kind else { continue }
      let collected = hand.payments[input.winnerID] ?? 0
      if collected > (biggest?.collected ?? 0) {
        biggest = (input.winnerID, collected, input.lineLabel ?? "\(input.basePoints) base")
      }
      wins[input.winnerID, default: 0] += 1
      if input.jokerless { jokerlessWins[input.winnerID, default: 0] += 1 }
    }

    if let biggest {
      result.append(
        Highlight(
          title: "Biggest hand",
          value: "\(name(biggest.id)) \u{00B7} \(biggest.label) \u{00B7} \(biggest.collected) pts"))
    }
    if let line = Self.countLine(wins, seats: session.seatIDs, names: names, unit: "win") {
      result.append(Highlight(title: "Most wins", value: line))
    }
    if let line = Self.countLine(jokerlessWins, seats: session.seatIDs, names: names, unit: "jokerless win") {
      result.append(Highlight(title: "Most jokerless", value: line))
    }
    return result
  }

  /// "Bea (2 wins)", or "Alex & Bea (1 win each)" for a tie. Nil when nobody has any.
  private static func countLine(_ counts: [String: Int], seats: [String], names: [String: String], unit: String) -> String? {
    guard let top = counts.values.max(), top > 0 else { return nil }
    let leaders = seats.filter { counts[$0] == top }.map { names[$0] ?? "Player" }
    let plural = top == 1 ? unit : unit + "s"
    if leaders.count == 1 { return "\(leaders[0]) (\(top) \(plural))" }
    return "\(leaders.joined(separator: " & ")) (\(top) \(plural) each)"
  }

  /// "Cy pays Alex $1.25"
  func settleLines(names: [String: String]) -> [String] {
    transfers.map { transfer in
      let from = names[transfer.fromID] ?? "Player"
      let to = names[transfer.toID] ?? "Player"
      let money = Scoring.formatMoney(cents: transfer.cents, symbol: session.rules.money.currencySymbol)
      return "\(from) pays \(to) \(money)"
    }
  }

  func shareText(names: [String: String], dateText: String) -> String {
    var lines = ["Mahjong game night", dateText, ""]
    for standing in standings {
      let name = names[standing.id] ?? "Player"
      var line = "\(standing.rank). \(name) \(Self.signed(standing.points)) pts"
      if session.rules.money.enabled {
        let money = Scoring.formatMoney(cents: abs(standing.cents), symbol: session.rules.money.currencySymbol)
        line += " (\(standing.cents < 0 ? "\u{2212}" : "+")\(money))"
      }
      lines.append(line)
    }
    let settle = settleLines(names: names)
    if !settle.isEmpty {
      lines.append("")
      lines.append("Settle up")
      lines.append(contentsOf: settle)
    }
    lines.append("")
    lines.append("Kept with Mahjong Mania")
    return lines.joined(separator: "\n")
  }

  static func signed(_ points: Int) -> String {
    if points > 0 { return "+\(points)" }
    if points < 0 { return "\u{2212}\(-points)" }
    return "0"
  }
}

extension SummaryModel {
  /// "Won by Bea", "Tied: Alex & Bea" or "No winner".
  func winnerText(names: [String: String]) -> String {
    let leaders = leaderIDs.compactMap { names[$0] }
    switch leaders.count {
    case 0: return "No winner"
    case 1: return "Won by \(leaders[0])"
    default: return "Tied: \(leaders.joined(separator: " & "))"
    }
  }
}

// MARK: - History grouping

struct MonthGroup: Identifiable, Equatable {
  let month: Date
  let sessions: [Session]
  var id: Date { month }
}

enum HistoryGrouping {
  /// Sessions grouped by calendar month, newest month first and newest session first inside each month.
  static func byMonth(_ sessions: [Session], calendar: Calendar = .current) -> [MonthGroup] {
    var buckets: [Date: [Session]] = [:]
    for session in sessions {
      let start =
        calendar.date(from: calendar.dateComponents([.year, .month], from: session.createdAt))
        ?? session.createdAt
      buckets[start, default: []].append(session)
    }
    return buckets.keys.sorted(by: >).map { month in
      MonthGroup(month: month, sessions: (buckets[month] ?? []).sorted { $0.createdAt > $1.createdAt })
    }
  }
}
