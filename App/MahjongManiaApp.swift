import SwiftUI

/// Launch-time switches used by UI tests.
enum LaunchOptions {
  /// `-UITestResetData`: start from an empty data directory and skip onboarding.
  static var resetData: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITestResetData")
  }
}

extension LaunchOptions {
  /// `-UITestDark`: force dark mode (the `-AppleInterfaceStyle` argument is not reliable on new simulators).
  static var forcedColorScheme: ColorScheme? {
    ProcessInfo.processInfo.arguments.contains("-UITestDark") ? .dark : nil
  }
}

@main
struct MahjongManiaApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.theme, Theme.standard)
        .preferredColorScheme(LaunchOptions.forcedColorScheme)
    }
  }
}
