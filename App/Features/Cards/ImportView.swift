import MahjongCore
import SwiftUI

/// Modal: paste a card file, check it line by line, import the valid hands (SPEC §11.7).
struct ImportView: View {
  private enum Destination: Hashable {
    case newCard, existing
  }

  /// Called with the ID of the card that received the hands, just before the sheet closes.
  var onImported: (String) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @Environment(CardsStore.self) private var cards

  @State private var text = ""
  @State private var destination: Destination = .newCard
  @State private var newName = ""
  @State private var existingID: String?
  @State private var report: ImportReport?
  @FocusState private var textFocused: Bool

  var body: some View {
    NavigationStack {
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          pasteArea
          destinationSection
          Button(action: check) {
            Label("Check", systemImage: "checklist")
          }
          .buttonStyle(PrimaryButton(.secondary, fullWidth: true))
          .disabled(text.allSatisfy { $0.isWhitespace })
          .accessibilityIdentifier("import.check")
          if let report { results(report) }
          Button(report?.importTitle ?? "Import hands", action: performImport)
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .disabled(!canImport)
            .accessibilityIdentifier("import.confirm")
        }
      }
      .navigationTitle("Import hands")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("import.cancel")
        }
        ToolbarItem(placement: .keyboard) {
          Button("Done") { textFocused = false }
            .accessibilityIdentifier("import.keyboardDone")
        }
      }
      .onChange(of: text) { _, _ in report = nil }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  // MARK: Paste

  private var pasteArea: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      HStack {
        Text("Paste a card file")
          .h2Style()
          .foregroundStyle(theme.text)
        Spacer(minLength: Spacing.sm)
        PasteButton(payloadType: String.self) { strings in
          text = strings.joined(separator: "\n")
        }
        .tint(theme.primary)
        .accessibilityIdentifier("import.paste")
        Button("Clear") { text = "" }
          .font(Typography.body)
          .foregroundStyle(theme.primary)
          .frame(minWidth: 44, minHeight: 44)
          .disabled(text.isEmpty)
          .accessibilityIdentifier("import.clear")
      }
      TextEditor(text: $text)
        .font(.system(.footnote, design: .monospaced))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .scrollContentBackground(.hidden)
        .focused($textFocused)
        .padding(Spacing.sm)
        .frame(minHeight: 160, maxHeight: 240)
        .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text("! My Card\n# Section\nFF 2026/x 2222/y 6666/y ; 25 ; X ; Name")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(theme.textFaint)
              .padding(.horizontal, Spacing.md)
              .padding(.vertical, Spacing.md)
              .allowsHitTesting(false)
              .accessibilityHidden(true)
          }
        }
        .accessibilityLabel("Card file text")
        .accessibilityIdentifier("import.text")
    }
  }

  // MARK: Destination

  private var destinationSection: some View {
    SectionCard("Import into") {
      if cards.records.isEmpty {
        Text("New card")
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
      } else {
        SegmentedPicker(
          "Destination", selection: $destination, options: [Destination.newCard, Destination.existing]
        ) { $0 == .newCard ? "New card" : "Add to existing" }
        .accessibilityIdentifier("import.destination")
      }
      switch destination {
      case .newCard:
        TextField("Card name (optional)", text: $newName)
          .textInputAutocapitalization(.words)
          .padding(Spacing.md)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
          .accessibilityIdentifier("import.name")
      case .existing:
        Picker("Card", selection: existingBinding) {
          ForEach(cards.records) { record in
            Text(record.name).tag(Optional(record.id))
          }
        }
        .pickerStyle(.menu)
        .tint(theme.primary)
        .accessibilityIdentifier("import.existing")
      }
    }
  }

  /// The chosen existing card, defaulting to the first one.
  private var existingBinding: Binding<String?> {
    Binding(
      get: { selectedExistingID },
      set: { existingID = $0 })
  }

  private var selectedExistingID: String? {
    if let existingID, cards.records.contains(where: { $0.id == existingID }) { return existingID }
    return cards.records.first?.id
  }

  // MARK: Results

  private func results(_ report: ImportReport) -> some View {
    SectionCard("Check") {
      Text(report.summary)
        .font(Typography.h2)
        .foregroundStyle(report.validCount > 0 ? theme.success : theme.danger)
        .accessibilityIdentifier("import.summary")
      if let problems = report.problemSummary {
        Text(problems)
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.danger)
          .accessibilityIdentifier("import.problems")
        ForEach(Array(report.problems.enumerated()), id: \.offset) { entry in
          problemRow(entry.element)
        }
      }
    }
  }

  private func problemRow(_ problem: CardFileError) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text("Line \(problem.lineNumber)")
        .tinyStyle()
        .foregroundStyle(theme.textMuted)
      Text(problem.text.trimmingCharacters(in: .whitespaces))
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(theme.text)
        .lineLimit(2)
      ForEach(Array(problem.errors.prefix(2).enumerated()), id: \.offset) { entry in
        Label {
          Text(entry.element.message)
            .font(Typography.small)
            .foregroundStyle(theme.danger)
        } icon: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(theme.danger)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, Spacing.xs)
  }

  // MARK: Actions

  private func check() {
    textFocused = false
    report = CardImport.check(text)
  }

  private var canImport: Bool {
    guard let report, report.validCount > 0 else { return false }
    return destination == .newCard || selectedExistingID != nil
  }

  private func performImport() {
    guard let report, report.validCount > 0 else { return }
    switch destination {
    case .newCard:
      let name = CardImport.cardName(typed: newName, report: report)
      let record = cards.createCard(
        name: name, year: report.year, text: CardImport.newCardText(name: name, report: report))
      finish(record.id)
    case .existing:
      guard let id = selectedExistingID else { return }
      cards.append(text: report.body, to: id)
      finish(id)
    }
  }

  private func finish(_ cardID: String) {
    onImported(cardID)
    dismiss()
  }
}

#Preview("Light") {
  let stores = AppStores.inMemory()
  return ImportView()
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  let stores = AppStores.inMemory()
  return ImportView()
    .environment(\.theme, Theme.standard)
    .environment(stores.cards)
    .preferredColorScheme(.dark)
}
