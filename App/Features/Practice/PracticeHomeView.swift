import MahjongCore
import SwiftUI

enum PracticeRoute: Hashable {
  case pickAHand
  case charleston
}

/// A lesson being played (presented full screen).
struct ActivePlay: Identifiable {
  let id = UUID()
  let session: LessonSession
}

/// Root of the Practice tab: header strip, the path, and free play.
struct PracticeHomeView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(PracticeStore.self) private var practice
  @Environment(SettingsStore.self) private var settings
  @State private var play: ActivePlay?
  @State private var detail: PathNode?
  @State private var testOutUnit: Int?
  @State private var scrollTarget: String?

  private var progress: PracticeProgress { practice.progress }

  var body: some View {
    ScrollViewReader { proxy in
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          if typeSize.isAccessibilitySize { HeaderStrip() }
          PathView(
            nodes: progress.nodes(), progress: progress,
            onTap: { handleTap($0) }, onTestOut: { testOutUnit = $0 })
          freePlay
        }
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        if !typeSize.isAccessibilitySize {
          HeaderStrip()
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(theme.bg)
            .overlay(alignment: .bottom) { Divider() }
        }
      }
      .onChange(of: scrollTarget) { _, id in
        guard let id else { return }
        withAnimation(.smooth(duration: 0.4)) { proxy.scrollTo(id, anchor: .center) }
        scrollTarget = nil
      }
      .task {
        practice.openDay()
        try? await Task.sleep(for: .milliseconds(150))
        if let next = progress.nextNode { proxy.scrollTo("node.\(next.id)", anchor: .center) }
        if let node = LaunchOptions.playNode(), play == nil { start(node) }
      }
    }
    .navigationTitle("Practice")
    .navigationBarTitleDisplayMode(.inline)
    .settingsToolbar()
    .navigationDestination(for: PracticeRoute.self) { route in
      switch route {
      case .pickAHand: PickAHandDrillView()
      case .charleston: CharlestonDrillView()
      }
    }
    .fullScreenCover(item: $play) { active in
      LessonView(
        session: active.session,
        onClose: {
          play = nil
          scrollTarget = progress.nextNode.map { "node.\($0.id)" }
        },
        onReplay: {
          let node = active.session.node
          let gold = active.session.gold
          let testOut = active.session.testOut
          play = nil
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            start(node, gold: gold, testOut: testOut)
          }
        })
    }
    .sheet(item: $detail) { node in
      NodeDetailSheet(node: node, progress: progress) { gold in
        detail = nil
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          start(node.spec, gold: gold)
        }
      }
      .presentationDetents([.medium, .large])
    }
    .confirmationDialog(
      "Test out of Unit \(testOutUnit ?? 0)?",
      isPresented: Binding(get: { testOutUnit != nil }, set: { if !$0 { testOutUnit = nil } }),
      titleVisibility: .visible
    ) {
      Button("Start the test") {
        if let unit = testOutUnit, let spec = Curriculum.unit(unit) { start(spec.checkpoint, testOut: true) }
        testOutUnit = nil
      }
      .accessibilityIdentifier("testout.start")
      Button("Not now", role: .cancel) {}
    } message: {
      Text("Get 8 of 10 right to skip this unit and everything before it.")
    }
  }

  // MARK: Actions

  private func handleTap(_ node: PathNode) {
    switch node.status {
    case .next: start(node.spec)
    case .locked, .done, .testedOut: detail = node
    }
  }

  func start(_ node: LessonSpec, gold: Bool = false, testOut: Bool = false) {
    let review = node.kind == .review
      ? progress.reviewQueue.due(today: practice.today, limit: Curriculum.reviewCount).map(\.exercise) : []
    let seed = LaunchOptions.practiceSeed() ?? UInt64.random(in: 1...999_999_999)
    let first = (progress.lessons[node.id]?.plays ?? 0) == 0 && LaunchOptions.playNode() == nil
    let session = LessonSession(
      node: node, gold: gold, testOut: testOut, seed: seed, review: review, showIntro: first)
    play = ActivePlay(session: session)
  }

  // MARK: Free play

  private var freePlay: some View {
    SectionCard("Free play") {
      VStack(spacing: 0) {
        NavigationLink(value: PracticeRoute.pickAHand) {
          FreePlayRow(
            symbol: "hand.point.up.left", title: "Pick-a-Hand",
            subtitle: "Look at 13 tiles and choose the line you would aim for.",
            badge: "Best streak \(progress.freePlay.pickStreakBest)")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.free.pick")
        Divider()
        NavigationLink(value: PracticeRoute.charleston) {
          FreePlayRow(
            symbol: "arrow.left.arrow.right", title: "Charleston Pass",
            subtitle: "Choose the 3 tiles you would pass and compare with the engine.",
            badge: "Best streak \(progress.freePlay.charlestonStreakBest)")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.free.charleston")
      }
    }
  }
}

struct FreePlayRow: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let symbol: String
  let title: String
  let subtitle: String
  var badge: String?

  var body: some View {
    HStack(alignment: .top, spacing: Spacing.md) {
      if !typeSize.isAccessibilitySize {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(theme.primary)
          .frame(width: 32, height: 32)
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Typography.body.weight(.semibold))
          .foregroundStyle(theme.text)
          .multilineTextAlignment(.leading)
        Text(subtitle)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        if let badge {
          Text(badge).tinyStyle().foregroundStyle(theme.gold).padding(.top, 2)
        }
      }
      Spacer(minLength: Spacing.sm)
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(theme.textFaint)
        .padding(.top, Spacing.sm)
        .accessibilityHidden(true)
    }
    .padding(.vertical, Spacing.md)
    .frame(minHeight: 44)
    .contentShape(Rectangle())
  }
}
