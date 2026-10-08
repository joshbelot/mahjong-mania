import Foundation

extension Notation {
  /// Canonical text of a line: `variants ; points ; X|C [; name] [; shift|shift2]`.
  public static func serialize(_ line: CardLine) -> String {
    var text = line.variants.map(\.source).joined(separator: " | ")
    text += " ; \(line.points) ; \(line.concealed ? "C" : "X")"
    let hasName = !(line.name ?? "").isEmpty
    if hasName || line.shift != .none {
      text += " ; \(line.name ?? "")"
    }
    switch line.shift {
    case .none: break
    case .consecutive: text += " ; shift"
    case .parity: text += " ; shift2"
    }
    return text
  }

  /// The card file format (SPEC §9.5): name, optional year, then sections in order with their lines.
  public static func serialize(_ card: Card) -> String {
    var out = "! \(card.name)\n"
    if let year = card.year { out += "!year \(year)\n" }
    for section in card.sections {
      out += "# \(section)\n"
      for line in card.lines where line.section == section {
        out += serialize(line) + "\n"
      }
    }
    return out
  }
}
