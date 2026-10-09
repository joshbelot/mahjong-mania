import MahjongCore
import SwiftUI

/// Renders one `LearnBlock`.
struct LearnBlockView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let block: LearnBlock
  /// Shows the raw notation text under examples (used by the Notation topic).
  var showSource = false

  var body: some View {
    switch block {
    case .paragraph(let text):
      Text(text)
        .font(Typography.body)
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    case .bullets(let items):
      VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(Array(items.enumerated()), id: \.offset) { entry in
          HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("•").foregroundStyle(theme.primary).accessibilityHidden(true)
            Text(entry.element)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
          }
          .font(Typography.body)
          .foregroundStyle(theme.text)
        }
      }
    case .steps(let items):
      VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(Array(items.enumerated()), id: \.offset) { entry in
          HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(entry.offset + 1).")
              .font(Typography.body.weight(.semibold).monospacedDigit())
              .foregroundStyle(theme.primary)
            Text(entry.element)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
          }
          .font(Typography.body)
          .foregroundStyle(theme.text)
        }
      }
    case .example(let notation, let caption):
      LearnExampleView(notation: notation, caption: caption, showSource: showSource)
    case .table(let header, let rows):
      tableView(header: header, rows: rows)
    case .note(let text):
      HStack(alignment: .top, spacing: Spacing.sm) {
        Image(systemName: "info.circle")
          .foregroundStyle(theme.primary)
          .accessibilityHidden(true)
        Text(text)
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(Spacing.md)
      .background(theme.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md))
    }
  }

  /// A grid at normal sizes; each row becomes a small stacked card at accessibility sizes.
  @ViewBuilder
  private func tableView(header: [String], rows: [[String]]) -> some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(Array(rows.enumerated()), id: \.offset) { row in
          VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
              if cell.offset == 0 {
                Text(cell.element).font(Typography.body.weight(.semibold))
              } else {
                let title = cell.offset < header.count ? header[cell.offset] : ""
                Text(title.isEmpty ? cell.element : "\(title): \(cell.element)")
                  .font(Typography.small)
                  .foregroundStyle(theme.textMuted)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Spacing.md)
          .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
        }
      }
    } else {
      Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: Spacing.sm) {
        GridRow {
          ForEach(Array(header.enumerated()), id: \.offset) { cell in
            Text(cell.element).tinyStyle().foregroundStyle(theme.textMuted)
          }
        }
        Divider()
        ForEach(Array(rows.enumerated()), id: \.offset) { row in
          GridRow {
            ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
              Text(cell.element)
                .font(cell.offset == 0 ? Typography.small.weight(.semibold) : Typography.small)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      .padding(Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
    }
  }
}

/// A card-file line drawn with `HandPatternView`, with a caption and a switch between the printed-card
/// look and real tiles.
struct LearnExampleView: View {
  @Environment(\.theme) private var theme
  @State private var showTiles = false
  let notation: String
  let caption: String
  let showSource: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      switch Notation.parseLine(notation) {
      case .success(let line):
        if let variant = line.variants.first {
          HandPatternView(
            variant: variant, line: line, mode: showTiles ? .tiles : .compact, tileSize: .small)
        }
        Text("\(line.points) points · \(line.concealed ? "Concealed" : "Exposed")")
          .font(Typography.small)
          .foregroundStyle(theme.textMuted)
        if showSource {
          Text(notation)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(theme.textMuted)
            .textSelection(.enabled)
        }
        Text(caption)
          .font(Typography.small)
          .foregroundStyle(theme.text)
          .fixedSize(horizontal: false, vertical: true)
        Button(showTiles ? "Show as printed" : "Show as tiles") {
          withAnimation(.smooth(duration: 0.2)) { showTiles.toggle() }
        }
        .font(Typography.small.weight(.semibold))
        .foregroundStyle(theme.primary)
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("learn.example.toggle")
      case .failure:
        Text(notation)
          .font(Typography.pattern)
          .foregroundStyle(theme.text)
        Text(caption)
          .font(Typography.small)
          .foregroundStyle(theme.text)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.md)
    .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md))
    .accessibilityElement(children: .contain)
  }
}
