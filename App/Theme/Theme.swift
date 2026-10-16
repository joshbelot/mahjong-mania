import SwiftUI

private struct ThemeKey: EnvironmentKey {
  static let defaultValue = Theme.standard
}

extension EnvironmentValues {
  var theme: Theme {
    get { self[ThemeKey.self] }
    set { self[ThemeKey.self] = newValue }
  }
}

private struct TileStyleKey: EnvironmentKey {
  static let defaultValue = TileStyle.classic
}

extension EnvironmentValues {
  /// How `TileView` draws tiles; set once at the app root from Settings.
  var tileStyle: TileStyle {
    get { self[TileStyleKey.self] }
    set { self[TileStyleKey.self] = newValue }
  }
}
