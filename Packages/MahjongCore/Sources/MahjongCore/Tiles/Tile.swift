import Foundation

public enum Suit: String, Codable, CaseIterable, Sendable {
  case cracks = "C"
  case bams = "B"
  case dots = "D"
}

public enum Wind: String, Codable, CaseIterable, Sendable {
  case north = "N"
  case east = "E"
  case west = "W"
  case south = "S"
}

/// `white` is the White Dragon, also called Soap, and doubles as zero in year hands.
public enum Dragon: String, Codable, CaseIterable, Sendable {
  case red = "R"
  case green = "G"
  case white = "0"
}

public enum Tile: Hashable, Comparable, Sendable, CaseIterable, Codable {
  case number(Int, Suit)  // value 1...9 (validated by `init?(code:)`)
  case wind(Wind)
  case dragon(Dragon)
  case flower
  case joker

  /// Order per SPEC §5.1: 1C…9C, 1B…9B, 1D…9D, N, E, W, S, R, G, 0, F, J.
  public static let allCases: [Tile] = {
    var tiles: [Tile] = []
    for suit in Suit.allCases {
      for value in 1...9 { tiles.append(.number(value, suit)) }
    }
    for wind in Wind.allCases { tiles.append(.wind(wind)) }
    for dragon in Dragon.allCases { tiles.append(.dragon(dragon)) }
    tiles.append(.flower)
    tiles.append(.joker)
    return tiles
  }()

  /// Position of the tile in `allCases`; used for sorting and the keyboard.
  public var sortIndex: Int {
    switch self {
    case .number(let value, let suit):
      let suitOffset: Int
      switch suit {
      case .cracks: suitOffset = 0
      case .bams: suitOffset = 1
      case .dots: suitOffset = 2
      }
      return suitOffset * 9 + (value - 1)
    case .wind(let wind):
      switch wind {
      case .north: return 27
      case .east: return 28
      case .west: return 29
      case .south: return 30
      }
    case .dragon(let dragon):
      switch dragon {
      case .red: return 31
      case .green: return 32
      case .white: return 33
      }
    case .flower: return 34
    case .joker: return 35
    }
  }

  public static func < (lhs: Tile, rhs: Tile) -> Bool {
    lhs.sortIndex < rhs.sortIndex
  }

  /// Parses "5D", "N", "R", "0", "F", "J". Returns nil for anything else (e.g. "0C", "10D", "X").
  public init?(code: String) {
    let chars = Array(code)
    switch chars.count {
    case 1:
      switch chars[0] {
      case "N": self = .wind(.north)
      case "E": self = .wind(.east)
      case "W": self = .wind(.west)
      case "S": self = .wind(.south)
      case "R": self = .dragon(.red)
      case "G": self = .dragon(.green)
      case "0": self = .dragon(.white)
      case "F": self = .flower
      case "J": self = .joker
      default: return nil
      }
    case 2:
      guard let value = chars[0].wholeNumberValue, (1...9).contains(value),
        chars[0].isASCII,
        let suit = Suit(rawValue: String(chars[1]))
      else { return nil }
      self = .number(value, suit)
    default:
      return nil
    }
  }

  /// Inverse of `init?(code:)`.
  public var code: String {
    switch self {
    case .number(let value, let suit): return "\(value)\(suit.rawValue)"
    case .wind(let wind): return wind.rawValue
    case .dragon(let dragon): return dragon.rawValue
    case .flower: return "F"
    case .joker: return "J"
    }
  }

  /// Physical copies in a set: 4 of each suited/honour tile, 8 flowers, 8 jokers.
  public var copies: Int {
    switch self {
    case .flower, .joker: return 8
    default: return 4
    }
  }

  public var name: String {
    switch self {
    case .number(let value, let suit):
      switch suit {
      case .cracks: return "\(value) Crack"
      case .bams: return "\(value) Bam"
      case .dots: return "\(value) Dot"
      }
    case .wind(let wind):
      switch wind {
      case .north: return "North"
      case .east: return "East"
      case .west: return "West"
      case .south: return "South"
      }
    case .dragon(let dragon):
      switch dragon {
      case .red: return "Red Dragon"
      case .green: return "Green Dragon"
      case .white: return "Soap (White Dragon)"
      }
    case .flower: return "Flower"
    case .joker: return "Joker"
    }
  }

  /// The dragon written in a suit's colour: Cracks ↔ Red, Bams ↔ Green, Dots ↔ Soap.
  public static func matchingDragon(_ suit: Suit) -> Tile {
    switch suit {
    case .cracks: return .dragon(.red)
    case .bams: return .dragon(.green)
    case .dots: return .dragon(.white)
    }
  }

  // MARK: Codable (encodes as the `code` string)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    guard let tile = Tile(code: value) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid tile code '\(value)'")
    }
    self = tile
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(code)
  }
}
