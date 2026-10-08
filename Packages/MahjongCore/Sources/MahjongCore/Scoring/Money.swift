import Foundation

extension Scoring {
  /// "$1.25", or "−$0.50" for negatives (U+2212 minus sign).
  public static func formatMoney(cents: Int, symbol: String) -> String {
    let absolute = cents.magnitude
    let whole = absolute / 100
    let fraction = absolute % 100
    let fractionText = fraction < 10 ? "0\(fraction)" : "\(fraction)"
    let body = "\(symbol)\(whole).\(fractionText)"
    return cents < 0 ? "\u{2212}\(body)" : body
  }
}
