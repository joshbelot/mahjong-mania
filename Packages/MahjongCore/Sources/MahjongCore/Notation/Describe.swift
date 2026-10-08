import Foundation

extension Notation {
  /// Plain-English description of one pattern variant (SPEC §9.7). Pieces are joined with " · ".
  public static func describe(_ variant: PatternVariant, shift: Shift, concealed: Bool) -> String {
    var pieces: [String] = []

    // Split the tokens into bodies: groups that came from the same body have adjacent ranges.
    var bodies: [[GroupSpec]] = []
    var previousEnd: Int?
    for token in variant.tokens {
      guard case .group(let spec, let range) = token else {
        previousEnd = nil
        continue
      }
      if let end = previousEnd, end == range.lowerBound, !bodies.isEmpty {
        bodies[bodies.count - 1].append(spec)
      } else {
        bodies.append([spec])
      }
      previousEnd = range.upperBound
    }
    for body in bodies { pieces.append(contentsOf: describeBody(body)) }

    let variables = Instantiate.variables(in: variant.groups)
    if variables.count == 2 {
      pieces.append("\(variables[0].displayLetter) and \(variables[1].displayLetter) are different suits.")
    } else if variables.count == 3 {
      pieces.append(
        "\(variables[0].displayLetter), \(variables[1].displayLetter) and \(variables[2].displayLetter) are different suits."
      )
    }

    switch shift {
    case .none: break
    case .consecutive:
      pieces.append("Numbers can be any consecutive/like set (example shown)")
    case .parity:
      pieces.append("Numbers can be any consecutive/like set, keeping odd/even (example shown)")
    }
    if concealed { pieces.append("Concealed — only the last tile may be called") }

    return pieces.joined(separator: " · ")
  }

  private static func groupNoun(_ count: Int) -> String {
    switch count {
    case 1: return "Single"
    case 2: return "Pair"
    case 3: return "Pung"
    case 4: return "Kong"
    case 5: return "Quint"
    case 6: return "Sextet"
    default: return "Set of \(count)"
    }
  }

  private static func refPhrase(_ ref: SuitRef) -> String {
    switch ref {
    case .variable(let v): return "suit \(v.displayLetter)"
    case .fixed(let suit):
      switch suit {
      case .cracks: return "Cracks"
      case .bams: return "Bams"
      case .dots: return "Dots"
      }
    }
  }

  private static func fixedName(_ tile: Tile) -> String {
    switch tile {
    case .dragon(.white): return "Soap"
    case .flower: return "Flowers"
    default: return tile.name
    }
  }

  private static func fixedPlural(_ tile: Tile) -> String {
    switch tile {
    case .wind(let wind): return "\(Tile.wind(wind).name) winds"
    case .dragon(.red): return "Red Dragons"
    case .dragon(.green): return "Green Dragons"
    default: return fixedName(tile)
    }
  }

  private static func describeBody(_ body: [GroupSpec]) -> [String] {
    // A body of two or more singles of numbers/Soap reads as a run: "2026 in suit A (0 is Soap)".
    if body.count >= 2, body.allSatisfy({ $0.count == 1 }) {
      var digits: [String] = []
      var ref: SuitRef?
      var hasSoap = false
      var allRunnable = true
      for group in body {
        switch group.tile {
        case .number(let value, let r):
          digits.append(String(value))
          ref = ref ?? r
        case .fixed(.dragon(.white)):
          digits.append("0")
          hasSoap = true
        default:
          allRunnable = false
        }
      }
      if allRunnable, let ref {
        var text = digits.joined(separator: hasSoap ? "" : " ")
        text += " in \(refPhrase(ref))"
        if hasSoap { text += " (0 is Soap)" }
        return [text]
      }
      // Singles of fixed tiles (e.g. NEWS): "One each of North, East, West and South".
      let fixedTiles: [Tile] = body.compactMap {
        if case .fixed(let tile) = $0.tile { return tile }
        return nil
      }
      if fixedTiles.count == body.count {
        let names = fixedTiles.map { fixedName($0) }
        let list = names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        return ["One each of \(list)"]
      }
    }
    return body.map(describeGroup)
  }

  private static func describeGroup(_ group: GroupSpec) -> String {
    let noun = groupNoun(group.count)
    switch group.tile {
    case .number(let value, let ref):
      if group.count == 1 { return "Single \(value) in \(refPhrase(ref))" }
      return "\(noun) of \(value)s in \(refPhrase(ref))"
    case .matchingDragon(let ref):
      if group.count == 1 { return "Single Dragon matching \(refPhrase(ref))" }
      return "\(noun) of Dragons matching \(refPhrase(ref))"
    case .fixed(let tile):
      if group.count == 1 {
        return "Single \(tile == .flower ? "Flower" : fixedName(tile))"
      }
      return "\(noun) of \(fixedPlural(tile))"
    }
  }
}
