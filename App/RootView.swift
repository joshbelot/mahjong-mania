import SwiftUI

struct RootView: View {
  @Environment(\.theme) private var theme
  @State private var showSettings = false

  var body: some View {
    TabView {
      tab("Game", symbol: "dice", id: "game")
      tab("Helper", symbol: "lightbulb", id: "helper")
      tab("Cards", symbol: "rectangle.stack", id: "cards")
      tab("Learn", symbol: "graduationcap", id: "learn")
    }
    .tint(theme.primary)
    .sheet(isPresented: $showSettings) {
      SettingsView()
    }
  }

  private func tab(_ title: String, symbol: String, id: String) -> some View {
    NavigationStack {
      PlaceholderScreen(title: title, symbol: symbol)
        .navigationTitle(title)
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
    }
    .tabItem { Label(title, systemImage: symbol) }
    .accessibilityIdentifier("tab.\(id)")
  }
}

struct PlaceholderScreen: View {
  @Environment(\.theme) private var theme
  let title: String
  let symbol: String

  var body: some View {
    ZStack {
      theme.bg.ignoresSafeArea()
      VStack(spacing: Spacing.md) {
        Image(systemName: symbol)
          .font(.system(size: 44))
          .foregroundStyle(theme.primary)
          .accessibilityHidden(true)
        Text(title)
          .titleStyle()
          .foregroundStyle(theme.text)
        Text("Coming soon")
          .font(Typography.body)
          .foregroundStyle(theme.textMuted)
      }
      .padding(Spacing.xl)
    }
  }
}

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme

  var body: some View {
    NavigationStack {
      ZStack {
        theme.bg.ignoresSafeArea()
        Text("Settings")
          .titleStyle()
          .foregroundStyle(theme.text)
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("settings.done")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

#Preview("Light") {
  RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView().preferredColorScheme(.dark)
}
