import MahjongCore
import SwiftUI

/// Moves points from one player to another (penalties, house rules). Also edits an existing adjustment.
struct AdjustmentSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  let sessionID: String
  let handID: String?
  let onSaved: () -> Void

  @State private var fromID: String?
  @State private var toID: String?
  @State private var points = 0
  @State private var note = ""
  @State private var loaded = false

  private static let quickPoints = [5, 10, 15, 20, 25]

  private var isValid: Bool {
    guard let fromID, let toID else { return false }
    return fromID != toID && points > 0
  }

  var body: some View {
    NavigationStack {
      Group {
        if let session = sessions.session(id: sessionID) {
          form(session)
        } else {
          EmptyStateView("Game night not found", systemImage: "questionmark.folder")
        }
      }
      .background(theme.bg)
      .navigationTitle("Adjustment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("adjust.cancel")
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .onAppear(perform: load)
  }

  private func form(_ session: Session) -> some View {
    ScreenContainer {
      VStack(alignment: .leading, spacing: Spacing.lg) {
        SectionCard("From") {
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(session.seatIDs, id: \.self) { id in
              let name = players.name(of: id)
              PlayerChipView(
                name: name, colorIndex: players.colorIndex(of: id), isSelected: fromID == id
              ) {
                fromID = id
                if toID == id { toID = nil }
              }
              .accessibilityIdentifier("adjust.from.\(name)")
            }
          }
        }
        SectionCard("To") {
          FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(session.seatIDs.filter { $0 != fromID }, id: \.self) { id in
              let name = players.name(of: id)
              PlayerChipView(
                name: name, colorIndex: players.colorIndex(of: id), isSelected: toID == id
              ) { toID = id }
              .accessibilityIdentifier("adjust.to.\(name)")
            }
          }
        }
        SectionCard("Points") {
          VStack(alignment: .leading, spacing: Spacing.md) {
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
              ForEach(Self.quickPoints, id: \.self) { value in
                ChipView("\(value)", isSelected: points == value) { points = value }
                  .accessibilityIdentifier("adjust.points.\(value)")
              }
            }
            StepperField("Points", value: $points, step: 5, range: 0...500, unit: "pts")
          }
        }
        SectionCard("Note") {
          TextField("Optional note", text: $note)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
            .accessibilityIdentifier("adjust.note")
        }
        Text("Moves points from one player to another. Use it for penalties or house rules. The dealer does not change.")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      Button(handID == nil ? "Save" : "Save changes") { save() }
        .buttonStyle(PrimaryButton(.primary, size: .large))
        .disabled(!isValid)
        .accessibilityIdentifier("adjust.save")
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
    }
  }

  private func load() {
    guard !loaded else { return }
    loaded = true
    guard let handID, let session = sessions.session(id: sessionID),
      let hand = session.hands.first(where: { $0.id == handID }),
      case .adjustment(let from, let to, let amount, let existingNote) = hand.kind
    else { return }
    fromID = from
    toID = to
    points = amount
    note = existingNote ?? ""
  }

  private func save() {
    guard isValid, let fromID, let toID else { return }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let kind = HandKind.adjustment(
      fromID: fromID, toID: toID, points: points, note: trimmed.isEmpty ? nil : trimmed)
    if let handID {
      sessions.editHand(id: handID, to: kind, in: sessionID)
    } else {
      sessions.addHand(kind, to: sessionID)
    }
    onSaved()
    dismiss()
  }
}

#if DEBUG
  #Preview("Light") {
    let sample = GameSamples.stores()
    return Color.clear.sheet(isPresented: .constant(true)) {
      AdjustmentSheet(sessionID: sample.sessionID, handID: nil) {}
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    let sample = GameSamples.stores()
    return Color.clear.sheet(isPresented: .constant(true)) {
      AdjustmentSheet(sessionID: sample.sessionID, handID: nil) {}
    }
    .gameStores(sample.stores)
    .preferredColorScheme(.dark)
  }
#endif
