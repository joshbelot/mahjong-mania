import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme

  var body: some View {
    NavigationStack {
      List {
        // Phase 12: replace this placeholder with the real settings sections.
        Section {
          Text("Settings will appear here.")
            .font(Typography.body)
            .foregroundStyle(theme.textMuted)
        }
        .listRowBackground(theme.surface)
        #if DEBUG
          Section("Developer") {
            NavigationLink("Component gallery") {
              ComponentGalleryView()
            }
            .accessibilityIdentifier("gallery.open")
          }
          .listRowBackground(theme.surface)
        #endif
      }
      .scrollContentBackground(.hidden)
      .background(theme.bg)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("settings.done")
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
}

#Preview("Light") {
  SettingsView().preferredColorScheme(.light)
}

#Preview("Dark") {
  SettingsView().preferredColorScheme(.dark)
}
