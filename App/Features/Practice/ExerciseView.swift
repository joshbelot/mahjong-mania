import MahjongCore
import SwiftUI

/// A big answer button used by every multiple-choice exercise.
struct ChoiceButtonStyle: ButtonStyle {
  enum Mark { case none, selected, right, wrong }
  @Environment(\.theme) private var theme
  var mark: Mark = .none
  var dimmed = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(Spacing.md)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(configuration.isPressed && mark == .none ? theme.primarySoft : background, in: RoundedRectangle(cornerRadius: Radius.md))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.md).strokeBorder(
          configuration.isPressed && mark == .none ? theme.primary : border, lineWidth: mark == .none && !configuration.isPressed ? 1 : 2))
      .opacity(dimmed ? 0.35 : 1)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
      .contentShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private var background: Color {
    switch mark {
    case .none: return theme.surface
    case .selected: return theme.primarySoft
    case .right: return theme.success.opacity(0.18)
    case .wrong: return theme.warning.opacity(0.2)
    }
  }

  private var border: Color {
    switch mark {
    case .none: return theme.border
    case .selected: return theme.primary
    case .right: return theme.success
    case .wrong: return theme.warning
    }
  }
}

/// Renders one question and its answer controls. All state lives in the session.
struct ExerciseView: View {
  @Environment(\.theme) private var theme
  @Environment(\.reduceMotion) private var reduceMotion
  let session: LessonSession
  let exercise: Exercise

  private var answering: Bool { session.phase == .answering }

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.lg) {
      if session.isReask {
        Label("Let's try that one again", systemImage: "arrow.counterclockwise")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.warning)
          .accessibilityIdentifier("lesson.reask")
      }
      Text(exercise.prompt)
        .font(Typography.h2)
        .foregroundStyle(theme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("lesson.prompt")
      linesView
      if let hint = session.hint, !hint.text.isEmpty {
        HStack(alignment: .top, spacing: Spacing.sm) {
          SunnyView(expression: .thinking, size: 34).frame(width: 46, height: 40)
          Text(hint.text)
          .font(Typography.small.weight(.medium))
          .foregroundStyle(theme.text)
        }
          .padding(Spacing.md)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(theme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: Radius.md))
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("lesson.hint")
      }
      tilesView
      if let message = session.message {
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .font(Typography.small.weight(.semibold))
          .foregroundStyle(theme.warning)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("lesson.message")
      }
      controls
        .shake(session.wrongCount)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Lines

  @ViewBuilder
  private var linesView: some View {
    let lines = exercise.lines + (session.hint?.lines ?? [])
    if !lines.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        if let caption = exercise.caption {
          Text(caption).tinyStyle().foregroundStyle(theme.textMuted)
        }
        ForEach(lines, id: \.id) { line in
          DrillLineSummary(line: line)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(theme.border, lineWidth: 1))
        }
      }
      .accessibilityIdentifier("lesson.lines")
    }
  }

  // MARK: Tiles

  @ViewBuilder
  private var tilesView: some View {
    if exercise.selectCount > 0 {
      rack(selectable: true)
        .shake(session.wrongCount)
    } else if !exercise.groups.isEmpty {
      FlowLayout(spacing: Spacing.md, lineSpacing: Spacing.md) {
        ForEach(Array(exercise.groups.enumerated()), id: \.offset) { entry in
          HStack(spacing: 3) {
            ForEach(Array(entry.element.enumerated()), id: \.offset) { tile in
              TileView(tile: tile.element, size: exercise.groups.count > 4 ? .small : .medium)
            }
          }
          .padding(Spacing.xs)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Spacing.sm)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("lesson.hand")
    } else if !exercise.tiles.isEmpty {
      rack(selectable: false)
    }
  }

  private func rack(selectable: Bool) -> some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      FlowLayout(spacing: 4, lineSpacing: 10) {
        ForEach(Array(exercise.tiles.enumerated()), id: \.offset) { entry in
          let selected = session.selectedTiles.contains(entry.offset)
          let tile = TileView(tile: entry.element, size: .medium, state: selected ? .selected : .normal)
            .overlay(alignment: .topTrailing) {
              if session.highlightedTiles.contains(entry.offset) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(theme.success, theme.surface)
                  .offset(x: 4, y: -4)
              }
            }
          if selectable {
            Button {
              session.toggleTile(entry.offset)
            } label: {
              tile.frame(minWidth: 44, minHeight: 58)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(answering)
            .accessibilityLabel(entry.element.name)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("lesson.tile.\(entry.offset)")
          } else {
            tile
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Spacing.md)
      .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.border, lineWidth: 1))
      if selectable {
        Text("Selected \(session.selectedTiles.count) of \(exercise.selectCount)")
          .font(Typography.small.weight(.semibold).monospacedDigit())
          .foregroundStyle(theme.textMuted)
          .accessibilityIdentifier("lesson.count")
      }
    }
  }

  // MARK: Controls

  @ViewBuilder
  private var controls: some View {
    if exercise.id.type == .keepOrPass {
      keepOrPass
    } else if exercise.selectCount > 0 {
      EmptyView()
    } else if exercise.choices.isEmpty {
      EmptyView()
    } else if exercise.choices.allSatisfy({ if case .yesNo = $0 { return true } else { return false } }) {
      HStack(spacing: Spacing.md) {
        ForEach(Array(exercise.choices.enumerated()), id: \.offset) { entry in
          choiceButton(entry.offset) {
            if case .yesNo(let yes) = entry.element {
              Text(yes ? "Yes" : "No").font(Typography.h2).foregroundStyle(theme.text)
            }
          }
        }
      }
    } else if exercise.choices.allSatisfy({ if case .tile = $0 { return true } else { return false } }) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Spacing.md)], spacing: Spacing.md) {
        ForEach(Array(exercise.choices.enumerated()), id: \.offset) { entry in
          choiceButton(entry.offset) {
            if case .tile(let tile) = entry.element { TileView(tile: tile, size: .medium).padding(.vertical, 2) }
          }
        }
      }
    } else if exercise.choices.allSatisfy({ if case .number = $0 { return true } else { return false } }) {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
        ForEach(Array(exercise.choices.enumerated()), id: \.offset) { entry in
          choiceButton(entry.offset) {
            if case .number(let n) = entry.element {
              Text("\(n)").font(.largeTitle.weight(.semibold)).foregroundStyle(theme.text)
            }
          }
        }
      }
    } else {
      VStack(spacing: Spacing.sm) {
        ForEach(Array(exercise.choices.enumerated()), id: \.offset) { entry in
          choiceButton(entry.offset) {
            switch entry.element {
            case .text(let text):
              Text(text).font(Typography.body.weight(.semibold)).foregroundStyle(theme.text)
                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            case .line(let line):
              DrillLineSummary(line: line)
            default:
              EmptyView()
            }
          }
        }
      }
    }
  }

  private func choiceButton<Label: View>(_ index: Int, @ViewBuilder label: () -> Label) -> some View {
    let removed = session.removedChoices.contains(index)
    return Button {
      session.select(choice: index)
    } label: {
      label()
    }
    .buttonStyle(ChoiceButtonStyle(mark: mark(for: index), dimmed: removed))
    .pop(trigger: session.answerCount, enabled: session.phase == .feedback && session.choice == index && session.grade?.correct == true)
    .disabled(!answering || removed)
    .accessibilityValue(accessibilityValue(index))
    .accessibilityAddTraits(session.choice == index ? .isSelected : [])
    .accessibilityIdentifier("lesson.choice.\(index)")
  }

  private func accessibilityValue(_ index: Int) -> String {
    guard LaunchOptions.revealAnswers, let right = exercise.isChoiceCorrect(index) else { return "" }
    return right ? "correct" : "wrong"
  }

  private func mark(for index: Int) -> ChoiceButtonStyle.Mark {
    if session.phase == .feedback {
      if session.choice == index { return session.grade?.correct == true ? .right : .wrong }
      if session.grade?.correct == false, exercise.isChoiceCorrect(index) == true { return .right }
      return .none
    }
    return session.choice == index ? .selected : .none
  }

  // MARK: Keep or pass

  private var keepOrPass: some View {
    VStack(spacing: Spacing.lg) {
      HStack(spacing: Spacing.sm) {
        ForEach(0..<exercise.queue.count, id: \.self) { i in
          Circle()
            .fill(dotColor(i))
            .frame(width: 12, height: 12)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Tile \(min(session.decisions.count + 1, exercise.queue.count)) of \(exercise.queue.count)")
      if let tile = session.currentQueueTile {
        TileView(tile: tile, size: .large)
          .scaleEffect(1.5)
          .frame(width: 52 * 1.5, height: 70 * 1.5)
          .padding(.vertical, Spacing.md)
          .accessibilityIdentifier("lesson.queue.tile")
        HStack(spacing: Spacing.md) {
          Button { session.decide(keep: true) } label: {
            Text("Keep").font(Typography.h2).foregroundStyle(theme.text)
          }
          .buttonStyle(ChoiceButtonStyle(mark: .none))
          .accessibilityIdentifier("lesson.keep")
          Button { session.decide(keep: false) } label: {
            Text("Pass").font(Typography.h2).foregroundStyle(theme.text)
          }
          .buttonStyle(ChoiceButtonStyle(mark: .none))
          .accessibilityIdentifier("lesson.pass")
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func dotColor(_ i: Int) -> Color {
    if i < session.decisionMarks.count { return session.decisionMarks[i] ? theme.success : theme.warning }
    return i == session.decisions.count ? theme.primary : theme.border
  }
}
