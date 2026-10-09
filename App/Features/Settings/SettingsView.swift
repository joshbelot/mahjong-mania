import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var store
  @Environment(AppStores.self) private var stores
  @State private var confirmFirst = false
  @State private var confirmSecond = false

  private var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = info?["CFBundleVersion"] as? String ?? "1"
    return "\(short) (\(build))"
  }

  var body: some View {
    NavigationStack {
      List {
        assistSection
        appearanceSection
        rulesSection
        moneySection
        helperSection
        aboutSection
        resetSection
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
      .confirmationDialog(
        "Delete all data?", isPresented: $confirmFirst, titleVisibility: .visible
      ) {
        Button("Continue…", role: .destructive) { confirmSecond = true }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This removes every player, game night, card and setting on this phone.")
      }
      .alert("This cannot be undone", isPresented: $confirmSecond) {
        Button("Delete everything", role: .destructive) {
          stores.resetAllData()
          dismiss()
        }
        .accessibilityIdentifier("settings.reset.confirm")
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("All players, game nights, cards and settings will be permanently deleted.")
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  // MARK: Sections

  private var assistSection: some View {
    Section {
      Picker("Assist level", selection: store.binding(\.assistLevel)) {
        ForEach(AssistLevel.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("settings.assist")
    } header: {
      Text("Help")
    } footer: {
      Text(
        "Off hides the Hand Helper. Peek shows help only when you ask. Coach shows suggestions and tips automatically."
      )
    }
    .listRowBackground(theme.surface)
  }

  private var appearanceSection: some View {
    Section("Appearance and feel") {
      Picker("Theme", selection: store.binding(\.theme)) {
        ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      .accessibilityIdentifier("settings.theme")
      Toggle("Haptics", isOn: store.binding(\.haptics))
        .accessibilityIdentifier("settings.haptics")
      Toggle("Keep screen awake during games", isOn: store.binding(\.keepAwake))
        .accessibilityIdentifier("settings.keepAwake")
    }
    .listRowBackground(theme.surface)
  }

  private var rulesSection: some View {
    Section {
      Stepper(
        "Discarder pays ×\(store.settings.defaultRules.discarderMultiplier)",
        value: store.binding(\.defaultRules.discarderMultiplier), in: 1...4)
      Stepper(
        "Others pay ×\(store.settings.defaultRules.othersOnDiscardMultiplier) on a discard",
        value: store.binding(\.defaultRules.othersOnDiscardMultiplier), in: 0...4)
      Stepper(
        "Self-pick ×\(store.settings.defaultRules.selfPickMultiplier)",
        value: store.binding(\.defaultRules.selfPickMultiplier), in: 1...4)
      Stepper(
        "Jokerless ×\(store.settings.defaultRules.jokerlessMultiplier)",
        value: store.binding(\.defaultRules.jokerlessMultiplier), in: 1...4)
      Toggle(
        "Jokerless bonus on hands with no joker groups",
        isOn: store.binding(\.defaultRules.jokerlessBonusForNoJokerLines))
    } header: {
      Text("Default rules")
    } footer: {
      Text("New game nights start with these payout rules. Each game night keeps its own copy.")
    }
    .listRowBackground(theme.surface)
  }

  private var moneySection: some View {
    Section("Money") {
      Toggle("Track money", isOn: store.binding(\.defaultRules.money.enabled))
        .accessibilityIdentifier("settings.money")
      Stepper(
        "\(store.settings.defaultRules.money.centsPerPoint)¢ per point",
        value: store.binding(\.defaultRules.money.centsPerPoint), in: 1...100)
      HStack {
        Text("Currency symbol")
        Spacer()
        TextField("$", text: store.binding(\.defaultRules.money.currencySymbol))
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 80)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }
    }
    .listRowBackground(theme.surface)
  }

  private var helperSection: some View {
    Section("Tiles") {
      Picker("Tile sort", selection: store.binding(\.tileSort)) {
        ForEach(TileSort.allCases, id: \.self) { Text($0.title).tag($0) }
      }
    }
    .listRowBackground(theme.surface)
  }

  private var aboutSection: some View {
    Section {
      LabeledContent("Version", value: version)
      Text(
        "Mahjong Mania is an independent app. Not affiliated with the National Mah Jongg League. Practice Card hands are original."
      )
      .font(Typography.small)
      .foregroundStyle(theme.textMuted)
      Text("Everything stays on your phone: no accounts, no tracking, no network.")
        .font(Typography.small)
        .foregroundStyle(theme.textMuted)
    } header: {
      Text("About")
    }
    .listRowBackground(theme.surface)
  }

  private var resetSection: some View {
    Section {
      Button("Reset all data", role: .destructive) { confirmFirst = true }
        .accessibilityIdentifier("settings.reset")
    }
    .listRowBackground(theme.surface)
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return SettingsView()
    .environment(stores.settings)
    .environment(stores)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return SettingsView()
    .environment(stores.settings)
    .environment(stores)
    .preferredColorScheme(.dark)
}
