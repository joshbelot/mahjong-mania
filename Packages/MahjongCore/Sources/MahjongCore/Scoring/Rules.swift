import Foundation

extension RuleSet {
  /// Standard NMJL-style rules: every built-in rule at its default (discarder pays double,
  /// self-pick doubles, jokerless doubles).
  public static let standard = RuleSet(id: "standard", name: "Standard")
}
