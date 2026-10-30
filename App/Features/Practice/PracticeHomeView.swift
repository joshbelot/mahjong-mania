import MahjongCore
import SwiftUI

enum PracticeRoute: Hashable {
  case freePlay(FreePlayMode)
  case profile
}

/// A play presented full screen: a path node, today's Daily Deal, or a review of mistakes.
struct ActivePlay: Identifiable {
  enum Flavor {
    case node
    case daily(DailyDealPlay)
    case review
  }

  let id = UUID()
  let session: LessonSession
  var flavor = Flavor.node
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
  @State private var nextBeforePlay: String?
  @State private var scrollTarget: String?
  @State private var popNodeID: String?
  @State private var speedTimed: Bool?
  @State private var nothingToReview = false
  @State private var popTick = 0
  @Environment(\.soundsEnabled) private var soundsEnabled

  private var progress: PracticeProgress { practice.progress }

  var body: some View {
    ScrollViewReader { proxy in
      ScreenContainer {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          if typeSize.isAccessibilitySize { HeaderStrip() }
          StreakBanners()
          TodaysDealNode { startDaily() }
          PathView(
            nodes: progress.nodes(), progress: progress, reviewDue: progress.reviewQueue.dueCount(today: practice.today),
            onTap: { handleTap($0) }, onTestOut: { testOutUnit = $0 }, popNodeID: popNodeID, popTick: popTick)
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
        // Streak news sits at the top of the path: leave it in view instead of scrolling past it.
        if practice.pendingStreakEvents.isEmpty, let next = progress.nextNode {
          proxy.scrollTo("node.\(next.id)", anchor: .center)
        }
        if let node = LaunchOptions.playNode(), play == nil { start(node) }
      }
    }
    .navigationTitle("Practice")
    .navigationBarTitleDisplayMode(.inline)
    .settingsToolbar()
    .navigationDestination(for: PracticeRoute.self) { route in
      switch route {
      case .freePlay(let mode): FreePlayView(mode: mode)
      case .profile: ProfileView()
      }
    }
    .fullScreenCover(item: $play) { active in
      playView(active)
    }
    .fullScreenCover(
      isPresented: Binding(get: { speedTimed != nil }, set: { if !$0 { speedTimed = nil } })
    ) {
      SpeedRoundView(
        timed: speedTimed ?? true,
        onClose: { speedTimed = nil },
        onReplay: {
          let timed = speedTimed ?? true
          speedTimed = nil
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            speedTimed = timed
          }
        })
    }
    .alert("Nothing to review", isPresented: $nothingToReview) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Questions you miss come back here the next day.")
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
      node: node, gold: gold, testOut: testOut, seed: seed, review: review,
      rules: settings.settings.defaultRules, showIntro: first)
    nextBeforePlay = progress.nextNode?.id
    play = ActivePlay(session: session)
  }

  @ViewBuilder
  private func playView(_ active: ActivePlay) -> some View {
    switch active.flavor {
    case .node:
      LessonView(
        session: active.session,
        onClose: {
          let before = nextBeforePlay
          play = nil
          let next = progress.nextNode
          scrollTarget = next.map { "node.\($0.id)" }
          if let next, next.id != before {
            popNodeID = next.id
            Task { @MainActor in
              try? await Task.sleep(for: .milliseconds(500))
              popTick += 1
              if soundsEnabled { SoundPlayer.shared.play(.unlock) }
            }
          }
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
    case .daily(let deal):
      LessonView(
        session: active.session, onClose: { play = nil },
        applyResult: { deal.finish($0, practice: practice) },
        completion: { session, outcome, next in
          AnyView(DailyDealResultView(play: deal, session: session, outcome: outcome, onContinue: next))
        })
    case .review:
      LessonView(
        session: active.session, onClose: { play = nil },
        applyResult: { practice.applyFreeReview($0.records) },
        completion: { session, outcome, next in
          AnyView(ReviewResultView(session: session, outcome: outcome, onContinue: next))
        })
    }
  }

  private func startDaily() {
    let day = practice.today
    let scored = progress.dailyDeals[day.description] == nil
    let deal = DailyDealPlay(day: day, analyzer: Analyzer.cached(for: PracticeCard.card), scored: scored)
    play = ActivePlay(session: deal.session(), flavor: .daily(deal))
  }

  private func startReview() {
    let due = progress.reviewQueue.due(today: practice.today, limit: ReviewQueue.sessionLimit).map(\.exercise)
    guard !due.isEmpty else {
      nothingToReview = true
      return
    }
    play = ActivePlay(session: LessonSession(title: "Review mistakes", ids: due), flavor: .review)
  }

  // MARK: Free play

  private var freePlay: some View {
    SectionCard("Free play") {
      VStack(spacing: 0) {
        speedRoundRow
        Divider()
        NavigationLink(value: PracticeRoute.freePlay(.pickAHand)) {
          FreePlayRow(
            symbol: "hand.point.up.left", title: "Pick-a-Hand",
            subtitle: "Look at 13 tiles and choose the hand you would aim for.",
            badge: "Best streak \(progress.freePlay.pickStreakBest)")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.free.pick")
        Divider()
        NavigationLink(value: PracticeRoute.freePlay(.charleston)) {
          FreePlayRow(
            symbol: "arrow.left.arrow.right", title: "Charleston Pass",
            subtitle: "Choose the 3 tiles you would pass and see how you did.",
            badge: "Best streak \(progress.freePlay.charlestonStreakBest)")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.free.charleston")
        Divider()
        Button(action: startReview) {
          let due = progress.reviewQueue.dueCount(today: practice.today)
          FreePlayRow(
            symbol: "arrow.counterclockwise", title: "Review mistakes",
            subtitle: due > 0 ? "\(due) \(due == 1 ? "question" : "questions") ready to try again." : "Nothing waiting. Questions you miss come back the next day.")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.free.review")
      }
    }
  }

  private var speedRoundRow: some View {
    let unlocked = progress.isUnitFinished(6)
    return Button {
      if unlocked { speedTimed = !settings.settings.speedRoundNoTimer }
    } label: {
      FreePlayRow(
        symbol: unlocked ? "bolt.fill" : "lock.fill", title: "Speed Round",
        subtitle: unlocked
          ? (settings.settings.speedRoundNoTimer ? "30 quick keep-or-pass questions, no clock." : "60 seconds of keep or pass. Right answers add time.")
          : "Finish Unit 6, Charleston basics, to unlock.",
        badge: unlocked ? "Best \(progress.speedBest)" : nil)
    }
    .buttonStyle(.plain)
    .disabled(!unlocked)
    .accessibilityIdentifier("practice.free.speed")
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
