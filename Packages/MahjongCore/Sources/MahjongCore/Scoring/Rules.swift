import Foundation

extension RuleSet {
  /// Standard NMJL-style payout rules: discarder pays double, self-pick doubles, jokerless doubles.
  public static let standard = RuleSet(id: "standard", name: "Standard")
}
