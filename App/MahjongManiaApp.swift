import SwiftUI

/// Launch-time switches used by UI tests.
enum LaunchOptions {
  /// `-UITestResetData`: start from an empty data directory and skip onboarding.
  static var resetData: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITestResetData")
  }
}

@main
struct MahjongManiaApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.theme, Theme.standard)
    }
  }
}
