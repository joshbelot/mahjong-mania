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
  @State private var stores = AppStores.live()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.theme, Theme.standard)
        .environment(stores.settings)
        .environment(stores.players)
        .environment(stores.sessions)
        .environment(stores.cards)
        .environment(stores.helper)
        .environment(stores)
        .preferredColorScheme(
          LaunchOptions.forcedColorScheme ?? stores.settings.settings.theme.colorScheme
        )
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { stores.flush() }
        }
    }
  }
}
