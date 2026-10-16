import Foundation

// MARK: Rule book types (SPEC §17.4)

/// The groups the rule book is listed under.
public enum RuleCategory: String, CaseIterable, Hashable, Codable, Sendable {
  case scoring, dealing, charleston, jokers, penalties, blanks

  public var title: String {
    switch self {
    case .scoring: return "Scoring"
    case .dealing: return "Dealing & turns"
    case .charleston: return "Charleston"
    case .jokers: return "Jokers & calling"
    case .penalties: return "Penalties"
    case .blanks: return "Blanks"
    }
  }
}

/// Options of the blanks rule (SPEC §17.5).
public struct BlankOptions: Hashable, Codable, Sendable {
  public var count: Int
  public var swapForJoker: Bool
  public var passInCharleston: Bool

  public init(count: Int = 6, swapForJoker: Bool = false, passInCharleston: Bool = true) {
    self.count = count
    self.swapForJoker = swapForJoker
    self.passInCharleston = passInCharleston
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 6
    swapForJoker = try c.decodeIfPresent(Bool.self, forKey: .swapForJoker) ?? false
    passInCharleston = try c.decodeIfPresent(Bool.self, forKey: .passInCharleston) ?? true
  }
}

/// When a custom scoring rule applies.
public enum RuleCondition: Hashable, Codable, Sendable {
  case always, selfPick, discard, jokerless, concealedHand, eastWins
  case section(String)
  case line(id: String, label: String)
}

/// Which losers a custom scoring rule changes.
public enum PayerScope: String, Hashable, Codable, Sendable {
  case everyone, discarderOnly, everyoneButDiscarder
}

public enum RuleAction: Hashable, Codable, Sendable {
  case multiply(Int)
  case addPoints(Int)
}

public struct CustomEffect: Hashable, Codable, Sendable {
  public var condition: RuleCondition
  public var payers: PayerScope
  public var action: RuleAction

  public init(condition: RuleCondition, payers: PayerScope, action: RuleAction) {
    self.condition = condition
    self.payers = payers
    self.action = action
  }
}

public struct CustomRule: Hashable, Codable, Sendable {
  public var title: String
  public var text: String
  /// nil = a written note for the table, with no effect on payments.
  public var effect: CustomEffect?

  public init(title: String, text: String, effect: CustomEffect? = nil) {
    self.title = title
    self.text = text
    self.effect = effect
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    effect = try c.decodeIfPresent(CustomEffect.self, forKey: .effect)
  }
}

public struct HouseRule: Identifiable, Hashable, Codable, Sendable {
  /// A built-in id from `RuleCatalog`, or `custom.<uuid>`.
  public var id: String
  public var isEnabled: Bool
  /// For rules with a "pays N×" choice.
  public var multiple: Int?
  /// `pay.jokerless` only.
  public var includeNoJokerHands: Bool?
  /// `table.blanks` only.
  public var blanks: BlankOptions?
  /// Custom rules only.
  public var custom: CustomRule?

  public init(
    id: String, isEnabled: Bool = true, multiple: Int? = nil, includeNoJokerHands: Bool? = nil,
    blanks: BlankOptions? = nil, custom: CustomRule? = nil
  ) {
    self.id = id
    self.isEnabled = isEnabled
    self.multiple = multiple
    self.includeNoJokerHands = includeNoJokerHands
    self.blanks = blanks
    self.custom = custom
  }

  public var isCustom: Bool { custom != nil }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    multiple = try c.decodeIfPresent(Int.self, forKey: .multiple)
    includeNoJokerHands = try c.decodeIfPresent(Bool.self, forKey: .includeNoJokerHands)
    blanks = try c.decodeIfPresent(BlankOptions.self, forKey: .blanks)
    custom = try c.decodeIfPresent(CustomRule.self, forKey: .custom)
  }

  public static func newCustomID() -> String { "custom.\(UUID().uuidString)" }
}

/// What a built-in rule is and how it starts. The wording shown to people lives in the app.
public struct RuleDefinition: Hashable, Sendable {
  public var id: String
  public var category: RuleCategory
  /// Locked rules are part of how the game works; they are listed but cannot be switched off.
  public var locked: Bool
  public var defaultEnabled: Bool
  public var defaultMultiple: Int?
  /// The allowed "pays N×" values, in the order they are offered.
  public var multipleChoices: [Int]

  public init(
    _ id: String, _ category: RuleCategory, locked: Bool = false, enabled: Bool = true,
    multiple: Int? = nil, choices: [Int] = []
  ) {
    self.id = id
    self.category = category
    self.locked = locked
    self.defaultEnabled = enabled
    self.defaultMultiple = multiple
    self.multipleChoices = choices
  }

  /// The rule as it starts out.
  public var defaultRule: HouseRule {
    HouseRule(
      id: id, isEnabled: locked ? true : defaultEnabled, multiple: defaultMultiple,
      includeNoJokerHands: id == RuleID.jokerless ? false : nil,
      blanks: id == RuleID.blanks ? BlankOptions() : nil)
  }
}

public enum RuleID {
  public static let discarder = "pay.discarder"
  public static let others = "pay.others"
  public static let selfPick = "pay.selfPick"
  public static let jokerless = "pay.jokerless"
  public static let discarderPaysAll = "pay.discarderPaysAll"
  public static let wall = "pay.wall"
  public static let dealEast = "deal.east"
  public static let dealRotate = "deal.rotate"
  public static let charlestonFirst = "charleston.first"
  public static let charlestonSecond = "charleston.second"
  public static let courtesy = "charleston.courtesy"
  public static let blind = "charleston.blind"
  public static let noJokers = "charleston.noJokers"
  public static let jokerGroups = "jokers.groups"
  public static let jokerExchange = "jokers.exchange"
  public static let calling = "calling"
  public static let concealed = "concealed"
  public static let deadHand = "deadHand"
  public static let blanks = "table.blanks"
}

public enum RuleCatalog {
  /// Every built-in rule, in the order the rule book lists them.
  public static let builtIns: [RuleDefinition] = [
    RuleDefinition(RuleID.discarder, .scoring, multiple: 2, choices: [1, 2, 3, 4]),
    RuleDefinition(RuleID.others, .scoring, multiple: 1, choices: [0, 1, 2]),
    RuleDefinition(RuleID.selfPick, .scoring, multiple: 2, choices: [1, 2, 3]),
    RuleDefinition(RuleID.jokerless, .scoring, multiple: 2, choices: [2, 3, 4]),
    RuleDefinition(RuleID.discarderPaysAll, .scoring, enabled: false),
    RuleDefinition(RuleID.wall, .scoring, locked: true),
    RuleDefinition(RuleID.dealEast, .dealing, locked: true),
    RuleDefinition(RuleID.dealRotate, .dealing, locked: true),
    RuleDefinition(RuleID.charlestonFirst, .charleston, locked: true),
    RuleDefinition(RuleID.charlestonSecond, .charleston),
    RuleDefinition(RuleID.courtesy, .charleston),
    RuleDefinition(RuleID.blind, .charleston),
    RuleDefinition(RuleID.noJokers, .charleston, locked: true),
    RuleDefinition(RuleID.jokerGroups, .jokers, locked: true),
    RuleDefinition(RuleID.jokerExchange, .jokers),
    RuleDefinition(RuleID.calling, .jokers, locked: true),
    RuleDefinition(RuleID.concealed, .jokers, locked: true),
    RuleDefinition(RuleID.deadHand, .penalties),
    RuleDefinition(RuleID.blanks, .blanks, enabled: false),
  ]

  public static func definition(for id: String) -> RuleDefinition? {
    builtIns.first { $0.id == id }
  }

  /// The built-ins, defaulted.
  public static var defaultRules: [HouseRule] { builtIns.map(\.defaultRule) }
}

// MARK: Rule set

public struct RuleSet: Identifiable, Hashable, Codable, Sendable {
  public var id: String
  public var name: String
  public var rules: [HouseRule]
  public var money: MoneySettings

  /// Built-ins missing from `rules` are added with their defaults (built-ins first, in catalog
  /// order, then custom rules), locked rules are forced on, and a built-in's missing choice is filled.
  public init(id: String, name: String, rules: [HouseRule]? = nil, money: MoneySettings = MoneySettings()) {
    self.id = id
    self.name = name
    self.rules = Self.normalised(rules ?? [])
    self.money = money
  }

  /// The v1 way to build a rule set: four multipliers and the no-joker bonus.
  public init(
    id: String, name: String, discarderMultiplier: Int, othersOnDiscardMultiplier: Int = 1,
    selfPickMultiplier: Int = 2, jokerlessMultiplier: Int = 2,
    jokerlessBonusForNoJokerLines: Bool = false, money: MoneySettings = MoneySettings()
  ) {
    self.init(id: id, name: name, rules: nil, money: money)
    self.discarderMultiplier = discarderMultiplier
    self.othersOnDiscardMultiplier = othersOnDiscardMultiplier
    self.selfPickMultiplier = selfPickMultiplier
    self.jokerlessMultiplier = jokerlessMultiplier
    self.jokerlessBonusForNoJokerLines = jokerlessBonusForNoJokerLines
  }

  static func normalised(_ given: [HouseRule]) -> [HouseRule] {
    var result: [HouseRule] = []
    for definition in RuleCatalog.builtIns {
      var rule = given.first { $0.id == definition.id } ?? definition.defaultRule
      if definition.locked { rule.isEnabled = true }
      if rule.multiple == nil { rule.multiple = definition.defaultMultiple }
      if definition.id == RuleID.jokerless, rule.includeNoJokerHands == nil { rule.includeNoJokerHands = false }
      if definition.id == RuleID.blanks, rule.blanks == nil { rule.blanks = BlankOptions() }
      result.append(rule)
    }
    let builtInIDs = Set(RuleCatalog.builtIns.map(\.id))
    var seenIDs = builtInIDs
    for rule in given where !builtInIDs.contains(rule.id) && seenIDs.insert(rule.id).inserted {
      result.append(rule)
    }
    return result
  }

  // MARK: Codable (reads v1.0 files)

  private enum CodingKeys: String, CodingKey {
    case id, name, rules, money
    case discarderMultiplier, othersOnDiscardMultiplier, selfPickMultiplier, jokerlessMultiplier
    case jokerlessBonusForNoJokerLines
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let id = try c.decode(String.self, forKey: .id)
    let name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Rules"
    let money = try c.decodeIfPresent(MoneySettings.self, forKey: .money) ?? MoneySettings()
    if let rules = try c.decodeIfPresent([HouseRule].self, forKey: .rules) {
      self.init(id: id, name: name, rules: rules, money: money)
      return
    }
    // A v1.0 file: four multipliers and one switch.
    self.init(id: id, name: name, rules: nil, money: money)
    if let value = try c.decodeIfPresent(Int.self, forKey: .discarderMultiplier) { discarderMultiplier = value }
    if let value = try c.decodeIfPresent(Int.self, forKey: .othersOnDiscardMultiplier) {
      othersOnDiscardMultiplier = value
    }
    if let value = try c.decodeIfPresent(Int.self, forKey: .selfPickMultiplier) { selfPickMultiplier = value }
    if let value = try c.decodeIfPresent(Int.self, forKey: .jokerlessMultiplier) { jokerlessMultiplier = value }
    if let value = try c.decodeIfPresent(Bool.self, forKey: .jokerlessBonusForNoJokerLines) {
      jokerlessBonusForNoJokerLines = value
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(rules, forKey: .rules)
    try c.encode(money, forKey: .money)
  }

  // MARK: Lookup

  public func rule(_ id: String) -> HouseRule? { rules.first { $0.id == id } }

  public func isOn(_ id: String) -> Bool { rule(id)?.isEnabled ?? false }

  /// The "pays N×" choice of a rule, whether or not it is switched on.
  public func multiple(_ id: String) -> Int? { rule(id)?.multiple }

  /// Changes one rule in place; does nothing if there is no such rule.
  public mutating func update(_ id: String, _ change: (inout HouseRule) -> Void) {
    guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
    change(&rules[index])
    if RuleCatalog.definition(for: id)?.locked == true { rules[index].isEnabled = true }
  }

  public mutating func setEnabled(_ id: String, _ enabled: Bool) { update(id) { $0.isEnabled = enabled } }

  public mutating func setMultiple(_ id: String, _ value: Int) { update(id) { $0.multiple = value } }

  public mutating func addCustom(_ newRule: HouseRule) {
    guard newRule.custom != nil, rule(newRule.id) == nil else { return }
    rules.append(newRule)
  }

  public mutating func removeCustom(id: String) {
    rules.removeAll { $0.id == id && $0.isCustom }
  }

  public var customRules: [HouseRule] { rules.filter(\.isCustom) }

  public var blanks: BlankOptions? {
    guard let rule = rule(RuleID.blanks), rule.isEnabled else { return nil }
    return rule.blanks ?? BlankOptions()
  }

  // MARK: v1 views of the rule book

  /// The multiplier a role rule has right now: its choice when on, otherwise 1.
  func roleMultiple(_ id: String) -> Int {
    guard let rule = rule(id), rule.isEnabled else { return 1 }
    return rule.multiple ?? 1
  }

  /// What the thrower pays on a discard win, as a multiple of the hand's points.
  public var discarderMultiplier: Int {
    get { multiple(RuleID.discarder) ?? 2 }
    set { update(RuleID.discarder) { $0.multiple = newValue; $0.isEnabled = true } }
  }
  public var othersOnDiscardMultiplier: Int {
    get { multiple(RuleID.others) ?? 1 }
    set { update(RuleID.others) { $0.multiple = newValue; $0.isEnabled = true } }
  }
  public var selfPickMultiplier: Int {
    get { multiple(RuleID.selfPick) ?? 2 }
    set { update(RuleID.selfPick) { $0.multiple = newValue; $0.isEnabled = true } }
  }
  public var jokerlessMultiplier: Int {
    get { multiple(RuleID.jokerless) ?? 2 }
    set { update(RuleID.jokerless) { $0.multiple = newValue; $0.isEnabled = true } }
  }
  public var jokerlessBonusForNoJokerLines: Bool {
    get { rule(RuleID.jokerless)?.includeNoJokerHands ?? false }
    set { update(RuleID.jokerless) { $0.includeNoJokerHands = newValue } }
  }
}
