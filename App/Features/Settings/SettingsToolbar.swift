import SwiftUI

private struct SettingsToolbarModifier: ViewModifier {
  @State private var showSettings = false

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Settings")
          .accessibilityIdentifier("settings.open")
        }
      }
      .sheet(isPresented: $showSettings) {
        SettingsView()
      }
  }
}

extension View {
  /// Adds the settings gear to the navigation bar and presents `SettingsView` as a sheet.
  /// Every tab root screen applies this.
  func settingsToolbar() -> some View {
    modifier(SettingsToolbarModifier())
  }
}
