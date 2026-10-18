import Foundation
import MahjongCore

/// UI-test launch arguments for the Helper. All of them are ignored unless `-UITestResetData` is also given.
///
/// - `-UITestHelperRack "<comma-separated tile codes>"`: start with this concealed rack.
/// - `-UITestHelperMode charleston|playing|scout`: start in this Helper mode.
/// - `-UITestAssist off|peek|coach`: start at this assist level.
/// - `-UITestOpenURL <url>`: open this link as if it had launched the app (card QR import).
/// - `-UITestTileStyle classic|traditional|largePrint|modern`: start with this tile style.
/// - `-UITestBlanks <n>`: switch the blanks rule on with n blanks.
/// - `-UITestTab game|helper|cards|learn`: start on this tab (game, helper, practice, cards, learn).
extension LaunchOptions {
  static func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
      return nil
    }
    return arguments[index + 1]
  }

  /// Tiles from a comma-separated list of codes; unknown codes are skipped.
  static func tiles(fromCodes text: String) -> [Tile] {
    text.split(separator: ",").compactMap { Tile(code: $0.trimmingCharacters(in: .whitespaces)) }
  }

  static func helperRack(arguments: [String] = ProcessInfo.processInfo.arguments) -> [Tile]? {
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestHelperRack", in: arguments)
    else { return nil }
    return tiles(fromCodes: text)
  }

  static func helperMode(arguments: [String] = ProcessInfo.processInfo.arguments) -> HelperMode? {
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestHelperMode", in: arguments)
    else { return nil }
    return HelperMode(rawValue: text)
  }

  /// `-UITestOpenURL <url>`: act as if this link had opened the app (with `-UITestResetData`).
  static var openURL: URL? {
    let arguments = ProcessInfo.processInfo.arguments
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestOpenURL", in: arguments)
    else { return nil }
    return URL(string: text)
  }

  static func blankCount(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int? {
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestBlanks", in: arguments), let count = Int(text)
    else { return nil }
    return count
  }

  static func initialTab(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppTab? {
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestTab", in: arguments)
    else { return nil }
    switch text {
    case "game": return .game
    case "helper": return .helper
    case "practice": return .practice
    case "cards": return .cards
    case "learn": return .learn
    default: return nil
    }
  }

  static func assistLevel(arguments: [String] = ProcessInfo.processInfo.arguments) -> AssistLevel? {
    guard arguments.contains("-UITestResetData"),
      let text = value(after: "-UITestAssist", in: arguments)
    else { return nil }
    return AssistLevel(rawValue: text)
  }
}

extension AppStores {
  /// Applies the Helper's UI-test launch arguments (see `LaunchOptions`).
  func applyHelperLaunchOptions(arguments: [String] = ProcessInfo.processInfo.arguments) {
    if let level = LaunchOptions.assistLevel(arguments: arguments) {
      settings.update { $0.assistLevel = level }
    }
    if let text = LaunchOptions.value(after: "-UITestTileStyle", in: arguments),
      arguments.contains("-UITestResetData"), let style = TileStyle(rawValue: text)
    {
      settings.update { $0.tileStyle = style }
    }
    if let count = LaunchOptions.blankCount(arguments: arguments) {
      settings.update {
        $0.defaultRules.update(RuleID.blanks) {
          $0.isEnabled = true
          $0.blanks = BlankOptions(count: count)
        }
      }
    }
    if let rack = LaunchOptions.helperRack(arguments: arguments) {
      helper.setRack(rack)
    }
    if let mode = LaunchOptions.helperMode(arguments: arguments) {
      helper.setMode(mode)
    }
  }
}
