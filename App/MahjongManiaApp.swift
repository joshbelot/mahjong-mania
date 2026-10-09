import SwiftUI

/// Launch-time switches used by UI tests.
enum LaunchOptions {
  /// `-UITestResetData`: start from an empty data directory and skip onboarding.
  static var resetData: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITestResetData")
  }

  /// `-UITestShowOnboarding`: like `-UITestResetData`, but onboarding is still shown.
  static var showOnboarding: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITestShowOnboarding")
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
  @State private var tips = TipCenter()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      Group {
        if stores.settings.settings.onboardingDone {
          RootView()
        } else {
          OnboardingView()
        }
      }
        .environment(\.theme, Theme.standard)
        .environment(tips)
        .environment(stores.settings)
        .environment(stores.players)
        .environment(stores.sessions)
        .environment(stores.cards)
        .environment(stores.helper)
        .environment(stores)
        .environment(\.hapticsEnabled, stores.settings.settings.haptics)
        .preferredColorScheme(
          LaunchOptions.forcedColorScheme ?? stores.settings.settings.theme.colorScheme
        )
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { stores.flush() }
        }
    }
  }
}
