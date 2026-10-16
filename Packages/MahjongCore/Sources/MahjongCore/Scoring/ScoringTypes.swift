import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var name: String
  public var colorIndex: Int
  public var archived: Bool
  public var createdAt: Date

  public init(id: String, name: String, colorIndex: Int, archived: Bool = false, createdAt: Date) {
    self.id = id
    self.name = name
    self.colorIndex = colorIndex
    self.archived = archived
    self.createdAt = createdAt
  }
}

public struct MoneySettings: Hashable, Codable, Sendable {
  public var enabled: Bool
  public var centsPerPoint: Int
  public var currencySymbol: String

  public init(enabled: Bool = false, centsPerPoint: Int = 1, currencySymbol: String = "$") {
    self.enabled = enabled
    self.centsPerPoint = centsPerPoint
    self.currencySymbol = currencySymbol
  }
}

public struct MahjongInput: Hashable, Codable, Sendable {
  public var winnerID: String
  /// nil = self-pick.
  public var discarderID: String?
  public var cardID: String?
  public var lineID: String?
  public var lineLabel: String?
  public var basePoints: Int
  public var jokerless: Bool
  public var lineHasNoJokerGroups: Bool
  public var note: String?
  /// The card section of the line (used by "a hand from section …" rules).
  public var lineSection: String?
  /// The line is marked C (used by "a concealed hand" rules).
  public var lineConcealed: Bool

  public init(
    winnerID: String, discarderID: String? = nil, cardID: String? = nil, lineID: String? = nil,
    lineLabel: String? = nil, basePoints: Int, jokerless: Bool = false,
    lineHasNoJokerGroups: Bool = false, note: String? = nil, lineSection: String? = nil,
    lineConcealed: Bool = false
  ) {
    self.lineSection = lineSection
    self.lineConcealed = lineConcealed
    self.winnerID = winnerID
    self.discarderID = discarderID
    self.cardID = cardID
    self.lineID = lineID
    self.lineLabel = lineLabel
    self.basePoints = basePoints
    self.jokerless = jokerless
    self.lineHasNoJokerGroups = lineHasNoJokerGroups
    self.note = note
  }

  /// Every key written by older versions stays readable; the new ones are optional.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    winnerID = try c.decode(String.self, forKey: .winnerID)
    discarderID = try c.decodeIfPresent(String.self, forKey: .discarderID)
    cardID = try c.decodeIfPresent(String.self, forKey: .cardID)
    lineID = try c.decodeIfPresent(String.self, forKey: .lineID)
    lineLabel = try c.decodeIfPresent(String.self, forKey: .lineLabel)
    basePoints = try c.decode(Int.self, forKey: .basePoints)
    jokerless = try c.decodeIfPresent(Bool.self, forKey: .jokerless) ?? false
    lineHasNoJokerGroups = try c.decodeIfPresent(Bool.self, forKey: .lineHasNoJokerGroups) ?? false
    note = try c.decodeIfPresent(String.self, forKey: .note)
    lineSection = try c.decodeIfPresent(String.self, forKey: .lineSection)
    lineConcealed = try c.decodeIfPresent(Bool.self, forKey: .lineConcealed) ?? false
  }
}

public enum HandKind: Hashable, Codable, Sendable {
  case mahjong(MahjongInput)
  case wall(note: String?)
  case adjustment(fromID: String, toID: String, points: Int, note: String?)

  /// Mahjong hands and wall games pass the deal to the next seat; adjustments do not.
  public var advancesDealer: Bool {
    switch self {
    case .mahjong, .wall: return true
    case .adjustment: return false
    }
  }
}

public struct HandRecord: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var createdAt: Date
  public var dealerID: String
  public var kind: HandKind
  /// playerID → ± points; sums to 0.
  public var payments: [String: Int]

  public init(id: String, createdAt: Date, dealerID: String, kind: HandKind, payments: [String: Int]) {
    self.id = id
    self.createdAt = createdAt
    self.dealerID = dealerID
    self.kind = kind
    self.payments = payments
  }
}

public struct Session: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var createdAt: Date
  public var endedAt: Date?
  /// 3...4 player IDs in play order.
  public var seatIDs: [String]
  public var startDealerIndex: Int
  public var cardID: String?
  /// Snapshot; changing it recomputes all hands.
  public var rules: RuleSet
  public var hands: [HandRecord]

  public init(
    id: String, createdAt: Date, endedAt: Date? = nil, seatIDs: [String], startDealerIndex: Int = 0,
    cardID: String? = nil, rules: RuleSet = .standard, hands: [HandRecord] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.endedAt = endedAt
    self.seatIDs = seatIDs
    self.startDealerIndex = startDealerIndex
    self.cardID = cardID
    self.rules = rules
    self.hands = hands
  }
}

public struct Transfer: Hashable, Sendable {
  public var fromID: String
  public var toID: String
  public var cents: Int

  public init(fromID: String, toID: String, cents: Int) {
    self.fromID = fromID
    self.toID = toID
    self.cents = cents
  }
}

public struct BiggestWin: Hashable, Sendable {
  public var points: Int
  public var lineLabel: String?
  public var date: Date

  public init(points: Int, lineLabel: String?, date: Date) {
    self.points = points
    self.lineLabel = lineLabel
    self.date = date
  }
}

public struct LineCount: Hashable, Sendable {
  public var label: String
  public var count: Int

  public init(label: String, count: Int) {
    self.label = label
    self.count = count
  }
}

public struct PlayerStats: Hashable, Sendable {
  public var sessionsPlayed = 0
  public var handsPlayed = 0
  public var wins = 0
  public var winRate = 0.0
  public var selfPicks = 0
  public var jokerlessWins = 0
  public var avgWinPoints = 0.0
  public var biggestWin: BiggestWin?
  public var timesDiscardedWinner = 0
  public var netPoints = 0
  public var netCents = 0
  public var favoriteLines: [LineCount] = []
  public var sessionWins = 0

  public init() {}
}

/// Namespace for the pure scoring functions (implemented across the files in this folder).
public enum Scoring {}
