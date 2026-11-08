import Foundation

/// Describes the same resolved target and tiles used to build a card-reading question.
enum ConcretePracticeFeedback {
  static func group(_ tiles: [Tile]) -> String {
    var order: [Tile] = []
    for tile in tiles where !order.contains(tile) { order.append(tile) }
    return order.map { tile in
      let count = tiles.filter { $0 == tile }.count
      return "\(count) × \(tile.name)"
    }.joined(separator: " and ")
  }

  static func target(_ target: Target, line: CardLine, groups: [[Tile]]) -> String {
    let listing = groups.map(group).joined(separator: ", ")
    var sentences = ["For \(line.displayName), this example has \(listing)."]
    for (index, shown) in groups.enumerated() where target.groups.indices.contains(index) {
      let expected = target.groups[index]
      let jokerCount = shown.filter { $0 == .joker }.count
      if jokerCount > 0 {
        sentences.append("\(jokerCount == 1 ? "The Joker replaces" : "The Jokers replace") \(expected.tile.name) in that group.")
      }
    }
    if line.variants.indices.contains(target.variantIndex) {
      let specs = line.variants[target.variantIndex].groups
      for expected in target.groups where specs.indices.contains(expected.groupIndex) {
        guard case .matchingDragon(let reference) = specs[expected.groupIndex].tile else { continue }
        let suit: Suit?
        switch reference {
        case .fixed(let value): suit = value
        case .variable(let variable): suit = target.binding.suit(for: variable)
        }
        if let suit {
          sentences.append("The \(expected.tile.name) matches \(suit.plainName).")
        }
      }
    }
    if line.shift != .none {
      let numbers = target.groups.compactMap { $0.tile.numberValue }
      let values = Array(Set(numbers)).sorted()
      if !values.isEmpty {
        if values.count == 1 {
          sentences.append("This line allows a shared number shift; the numbered groups here all use \(values[0]).")
        } else {
          let actual = values.map(String.init).joined(separator: ", ")
          let restriction = line.shift == .parity ? " while keeping odd or even numbers" : ""
          sentences.append("This line allows the numbers to shift together\(restriction); this example uses \(actual).")
        }
      }
    }
    return sentences.joined(separator: " ")
  }

  static func mismatch(shown: [[Tile]], valid: [[Tile]], target: Target, line: CardLine) -> String {
    let differences = shown.indices.compactMap { index -> String? in
      guard valid.indices.contains(index), shown[index].counts != valid[index].counts else { return nil }
      return "the shown group has \(group(shown[index])) where this example uses \(group(valid[index]))"
    }
    let detail = differences.isEmpty ? "the shown tiles do not match this line" : differences.joined(separator: "; ")
    let illegalJoker = shown.contains { $0.count <= 2 && $0.contains(.joker) }
    let rule = illegalJoker
      ? "A Joker cannot replace a tile in a single or pair; it may replace a tile only in a group of three or more."
      : "A line must match every group and its suit relationships."
    return "No. \(detail.capitalizedFirst). \(rule) "
      + self.target(target, line: line, groups: valid)
  }
}

private extension String {
  var capitalizedFirst: String {
    guard let first else { return self }
    return first.uppercased() + dropFirst()
  }
}
