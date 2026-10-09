import MahjongCore
import SwiftUI
import UIKit

/// What a sheet is editing: a new hand (`handID == nil`) or an existing one.
struct RecordTarget: Identifiable, Hashable {
  let handID: String?
  var id: String { handID ?? "new" }
}

/// The live scoreboard of a game night (read-only once it has ended).
struct ScoreboardView: View {
  @Environment(\.theme) private var theme
  @Environment(SettingsStore.self) private var settings
  @Environment(PlayersStore.self) private var players
  @Environment(SessionsStore.self) private var sessions
  let sessionID: String
  let onShowSummary: () -> Void

  @State private var recordTarget: RecordTarget?
  @State private var adjustmentTarget: RecordTarget?
  @State private var showRules = false
  @State private var confirmWall = false
  @State private var confirmEnd = false
  @State private var confirmReopen = false
  @State private var deleteHandID: String?
  @State private var confirmDelete = false
  @State private var flashID: String?
  @State private var savedTick = 0

  var body: some View {
    Group {
      if let session = sessions.session(id: sessionID) {
        content(session)
      } else {
        EmptyStateView("Game night not found", systemImage: "questionmark.folder")
      }
    }
    .background(theme.bg)
  }

  // MARK: Content

  @ViewBuilder
  private func content(_ session: Session) -> some View {
    let readOnly = session.endedAt != nil
    let totals = Scoring.totals(session)
    let money = Scoring.moneyTotals(session)
    let dealer = Scoring.currentDealerID(session)
    let leaders = SummaryModel(session: session).leaderIDs
    let names = players.nameMap(for: session.seatIDs)

    List {
      Section {
        ForEach(session.seatIDs, id: \.self) { id in
          seatRow(
            id: id, session: session, points: totals[id] ?? 0, cents: money[id] ?? 0,
            isDealer: id == dealer, isLeader: leaders.contains(id))
        }
      }

      if !readOnly {
        Section {
          Button {
            recordTarget = RecordTarget(handID: nil)
          } label: {
            Label("Record a hand", systemImage: "plus")
          }
          .buttonStyle(PrimaryButton(.primary, size: .large))
          .accessibilityIdentifier("score.record")
          .actionRowStyle()

          Button {
            confirmWall = true
          } label: {
            Text("Wall game")
          }
          .buttonStyle(PrimaryButton(.secondary, size: .large))
          .accessibilityIdentifier("score.wall")
          .actionRowStyle()
        }
      }

      Section {
        if session.hands.isEmpty {
          Text("No hands yet. Shuffle up!")
            .font(Typography.body)
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
            .listRowBackground(theme.surface)
            .accessibilityIdentifier("log.empty")
        } else {
          ForEach(Array(session.hands.enumerated().reversed()), id: \.element.id) { entry in
            logRow(
              number: entry.offset + 1, hand: entry.element, session: session, names: names,
              readOnly: readOnly)
          }
        }
      } header: {
        Text("Hand log")
          .foregroundStyle(theme.textMuted)
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .navigationTitle("Game night \u{00B7} \(session.createdAt.gameShortDate)")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) { menu(session, readOnly: readOnly) }
    }
    .sheet(item: $recordTarget) { target in
      RecordHandView(sessionID: sessionID, handID: target.handID) { winnerID in
        didSave(winnerID: winnerID)
      }
    }
    .sheet(item: $adjustmentTarget) { target in
      AdjustmentSheet(sessionID: sessionID, handID: target.handID) {
        savedTick += 1
      }
    }
    .sheet(isPresented: $showRules) {
      SessionRulesSheet(sessionID: sessionID)
    }
    .confirmationDialog("Record a wall game?", isPresented: $confirmWall, titleVisibility: .visible) {
      Button("Record wall game") {
        sessions.addHand(.wall(note: nil), to: sessionID)
        savedTick += 1
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("No one pays. The deal passes to the next player.")
    }
    .confirmationDialog("End this game night?", isPresented: $confirmEnd, titleVisibility: .visible) {
      Button("End game night", role: .destructive) {
        sessions.end(sessionID: sessionID)
        onShowSummary()
      }
      Button("Keep playing", role: .cancel) {}
    } message: {
      Text("You will see the final standings and who owes whom.")
    }
    .confirmationDialog(
      "Reopen this game night?", isPresented: $confirmReopen, titleVisibility: .visible
    ) {
      Button("Reopen") { sessions.reopen(sessionID: sessionID) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The game night in progress will be ended.")
    }
    .confirmationDialog(
      "Delete this hand?", isPresented: $confirmDelete, titleVisibility: .visible,
      presenting: deleteHandID
    ) { handID in
      Button("Delete hand", role: .destructive) {
        sessions.removeHand(id: handID, from: sessionID)
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("Totals and the dealer are recalculated.")
    }
    .sensoryFeedback(.success, trigger: settings.settings.haptics ? savedTick : 0)
    .onAppear { setAwake(!readOnly) }
    .onDisappear { setAwake(false) }
    .onChange(of: readOnly) { _, isReadOnly in setAwake(!isReadOnly) }
  }

  // MARK: Rows

  private func seatRow(id: String, session: Session, points: Int, cents: Int, isDealer: Bool, isLeader: Bool)
    -> some View
  {
    let name = players.name(of: id)
    return HStack(spacing: Spacing.md) {
      AvatarView(name: name, colorIndex: players.colorIndex(of: id), size: 48)
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(spacing: Spacing.xs) {
          Text(name)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .lineLimit(1)
          if isLeader {
            Image(systemName: "crown.fill")
              .font(.footnote)
              .foregroundStyle(theme.gold)
              .accessibilityLabel("Leader")
          }
        }
        if isDealer {
          BadgeView(.east)
            .accessibilityIdentifier("dealer.\(name)")
        }
      }
      Spacer(minLength: Spacing.sm)
      VStack(alignment: .trailing, spacing: 2) {
        ScorePointsText(points: points)
          .accessibilityIdentifier("score.\(name)")
        if session.rules.money.enabled {
          MoneyText(cents: cents, symbol: session.rules.money.currencySymbol)
            .accessibilityIdentifier("money.\(name)")
        }
      }
    }
    .frame(minHeight: 64)
    .listRowBackground(
      ZStack {
        theme.surface
        theme.gold.opacity(flashID == id ? 0.35 : 0)
      }
      .animation(.easeOut(duration: 0.6), value: flashID))
  }

  @ViewBuilder
  private func logRow(number: Int, hand: HandRecord, session: Session, names: [String: String], readOnly: Bool)
    -> some View
  {
    let entry = HandLogText.entry(for: hand, rules: session.rules, names: names)
    let label = HStack(spacing: Spacing.md) {
      Text("#\(number)")
        .font(Typography.small.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(theme.textMuted)
        .frame(width: 30, alignment: .leading)
      leadingIcon(for: hand)
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.leading)
        if !entry.meta.isEmpty {
          Text(entry.meta)
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .multilineTextAlignment(.leading)
        }
      }
      Spacer(minLength: Spacing.sm)
      trailingPoints(for: hand, entry: entry)
    }
    .frame(minHeight: 56)
    .contentShape(Rectangle())

    if readOnly {
      label
        .listRowBackground(theme.surface)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("log.row.\(number)")
    } else {
      Button {
        if case .adjustment = hand.kind {
          adjustmentTarget = RecordTarget(handID: hand.id)
        } else if case .mahjong = hand.kind {
          recordTarget = RecordTarget(handID: hand.id)
        }
      } label: {
        label
      }
      .buttonStyle(.plain)
      .listRowBackground(theme.surface)
      .accessibilityIdentifier("log.row.\(number)")
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button {
          deleteHandID = hand.id
          confirmDelete = true
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .tint(theme.danger)
      }
    }
  }

  @ViewBuilder
  private func leadingIcon(for hand: HandRecord) -> some View {
    switch hand.kind {
    case .mahjong(let input):
      AvatarView(
        name: players.name(of: input.winnerID), colorIndex: players.colorIndex(of: input.winnerID),
        size: 32)
    case .wall:
      Image(systemName: "square.dashed")
        .font(.title3)
        .foregroundStyle(theme.textMuted)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    case .adjustment:
      Image(systemName: "plusminus.circle")
        .font(.title3)
        .foregroundStyle(theme.textMuted)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
  }

  @ViewBuilder
  private func trailingPoints(for hand: HandRecord, entry: HandLogText.Entry) -> some View {
    switch hand.kind {
    case .mahjong:
      if let points = entry.points { PointsText(points) }
    case .wall:
      EmptyView()
    case .adjustment:
      if let points = entry.points {
        Text("\(points) pts")
          .font(Typography.body.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(theme.textMuted)
      }
    }
  }

  // MARK: Menu

  @ViewBuilder
  private func menu(_ session: Session, readOnly: Bool) -> some View {
    Menu {
      if readOnly {
        Button {
          onShowSummary()
        } label: {
          Label("Summary", systemImage: "chart.bar")
        }
        .accessibilityIdentifier("menu.summary")
        Button {
          if let active = sessions.activeSession, active.id != sessionID {
            confirmReopen = true
          } else {
            sessions.reopen(sessionID: sessionID)
          }
        } label: {
          Label("Reopen", systemImage: "arrow.uturn.backward.circle")
        }
        .accessibilityIdentifier("menu.reopen")
      } else {
        Button {
          sessions.undoLast(in: sessionID)
          savedTick += 1
        } label: {
          Label("Undo last", systemImage: "arrow.uturn.backward")
        }
        .disabled(session.hands.isEmpty)
        .accessibilityIdentifier("menu.undo")
        Button {
          adjustmentTarget = RecordTarget(handID: nil)
        } label: {
          Label("Adjustment", systemImage: "plusminus")
        }
        .accessibilityIdentifier("menu.adjustment")
        Button {
          showRules = true
        } label: {
          Label("Rules", systemImage: "slider.horizontal.3")
        }
        .accessibilityIdentifier("menu.rules")
        Button(role: .destructive) {
          confirmEnd = true
        } label: {
          Label("End game night", systemImage: "flag.checkered")
        }
        .accessibilityIdentifier("menu.end")
      }
    } label: {
      Image(systemName: "ellipsis.circle")
        .frame(minWidth: 44, minHeight: 44)
    }
    .accessibilityLabel("Game menu")
    .accessibilityIdentifier("score.menu")
  }

  // MARK: Actions

  private func didSave(winnerID: String) {
    savedTick += 1
    Task {
      try? await Task.sleep(for: .milliseconds(450))
      flashID = winnerID
      try? await Task.sleep(for: .milliseconds(700))
      flashID = nil
    }
  }

  private func setAwake(_ awake: Bool) {
    UIApplication.shared.isIdleTimerDisabled = awake && settings.settings.keepAwake
  }
}

private extension View {
  /// A transparent full-width List row for the big buttons.
  func actionRowStyle() -> some View {
    self
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: Spacing.sm, leading: 0, bottom: Spacing.sm, trailing: 0))
  }
}

/// Edits the rules of a running game night. Applying recomputes every hand.
struct SessionRulesSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(SessionsStore.self) private var sessions
  let sessionID: String
  @State private var rules = RuleSet.standard
  @State private var loaded = false

  var body: some View {
    NavigationStack {
      RulesEditorView(rules: $rules, showsMoney: true)
        .safeAreaInset(edge: .bottom) {
          Text("Applying new rules recalculates every hand in this game night.")
            .font(Typography.small)
            .foregroundStyle(theme.textMuted)
            .multilineTextAlignment(.center)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.bg)
        }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
              .accessibilityIdentifier("rules.cancel")
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Apply") {
              sessions.setRules(rules, in: sessionID)
              dismiss()
            }
            .accessibilityIdentifier("rules.apply")
          }
        }
    }
    .onAppear {
      guard !loaded else { return }
      loaded = true
      if let session = sessions.session(id: sessionID) { rules = session.rules }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
}

#if DEBUG
  #Preview("Light") {
    let sample = GameSamples.stores()
    return NavigationStack { ScoreboardView(sessionID: sample.sessionID, onShowSummary: {}) }
      .gameStores(sample.stores)
      .preferredColorScheme(.light)
  }

  #Preview("Dark") {
    let sample = GameSamples.stores()
    return NavigationStack { ScoreboardView(sessionID: sample.sessionID, onShowSummary: {}) }
      .gameStores(sample.stores)
      .preferredColorScheme(.dark)
  }
#endif
