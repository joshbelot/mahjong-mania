import CoreGraphics
import CoreText
import Foundation
import MahjongCore

public struct RenderOptions {
  public var grayscale = false
  public var retyped = false
  /// Blots and faded ink only make sense on pictures; a text layer would still read clearly.
  public var visualAmbiguity = true
  public var paper: CGColor = rgb(1, 1, 1)
  public init() {}
}

public enum PageRenderer {
  public static func pageSize(_ style: LayoutStyle) -> CGSize {
    style.landscape ? CGSize(width: 792, height: 612) : CGSize(width: 612, height: 792)
  }

  /// Draws a page into `ctx` whose coordinates are already top-left origin, in points.
  public static func draw(
    page: PageSpec, style baseStyle: LayoutStyle, options: RenderOptions, ctx: CGContext
  ) {
    let size = pageSize(baseStyle)
    let canvas = Canvas(ctx: ctx, fontName: baseStyle.fontName)
    ctx.setFillColor(options.paper)
    ctx.fill(CGRect(origin: .zero, size: size))

    let margin: CGFloat = 30
    let gutter: CGFloat = baseStyle.columns > 1 ? 36 : 0
    let colW = (size.width - 2 * margin - gutter * CGFloat(baseStyle.columns - 1)) / CGFloat(baseStyle.columns)
    let black = rgb(0.08, 0.08, 0.1)
    let scale = fitScale(page: page, style: baseStyle, canvas: canvas, colW: colW, options: options)
    let body = baseStyle.size * scale

    let titleSize = body * 1.5
    canvas.draw(
      "Sample Card \(page.id.suffix(2))", x: margin, baseline: margin + titleSize, size: titleSize,
      color: black)
    var column = 0
    let totalRows = page.sections.reduce(0) { $0 + $1.rows.count }
    let rowsPerColumn = Int((Double(totalRows) / Double(baseStyle.columns)).rounded(.up))
    var rowsInColumn = 0
    var y = margin + titleSize + body * 2.2
    let bottomLimit = size.height - margin - body * 5
    var footnoteY = size.height - margin - CGFloat(page.footnotes.count) * body * 1.6

    func colX() -> CGFloat { margin + CGFloat(column) * (colW + gutter) }

    for section in page.sections {
      let rowH = body * 1.6 + baseStyle.rowGap
      let needed = body * 2.2 + rowH * CGFloat(min(2, section.rows.count))
      if (y + needed > bottomLimit || rowsInColumn >= rowsPerColumn) && column + 1 < baseStyle.columns {
        column += 1
        rowsInColumn = 0
        y = margin + titleSize + body * 2.2
      }
      // Section title.
      let titleBase = y + body
      if baseStyle.titleBar {
        ctx.setFillColor(rgb(0.2, 0.2, 0.25))
        ctx.fill(CGRect(x: colX(), y: y - body * 0.2, width: colW, height: body * 1.6))
        canvas.draw(
          section.title.uppercased(), x: colX() + 8, baseline: titleBase, size: body,
          color: rgb(1, 1, 1))
      } else {
        let w = canvas.width(section.title.uppercased(), size: body)
        canvas.draw(
          section.title.uppercased(), x: colX() + (colW - w) / 2, baseline: titleBase, size: body,
          color: black)
      }
      y += body * 2.0
      if let header = baseStyle.header, section.title == page.sections.first?.title {
        drawHeader(header, canvas: canvas, x: colX(), colW: colW, y: y, body: body, color: black)
        y += body * 1.7
      }
      for (index, row) in section.rows.enumerated() {
        if (y + rowH > bottomLimit || rowsInColumn >= rowsPerColumn) && column + 1 < baseStyle.columns {
          column += 1
          rowsInColumn = 0
          y = margin + titleSize + body * 2.2
        }
        rowsInColumn += 1
        let rowNumber = index + 1
        let height = drawRow(
          row, number: rowNumber, style: baseStyle, canvas: canvas, x: colX(), colW: colW, y: y,
          body: body, options: options)
        y += height + baseStyle.rowGap
      }
      y += body * 0.8
    }
    for note in page.footnotes {
      canvas.draw(
        "\(note.marker) \(note.text)", x: margin, baseline: footnoteY, size: body * 0.95, color: black)
      footnoteY += body * 1.6
    }
  }

  // MARK: Pieces

  static func patternPieces(_ row: RowSpec, style: LayoutStyle, options: RenderOptions) -> [TextPiece] {
    let ink = rgb(0.08, 0.08, 0.1)
    var pieces: [TextPiece] = []
    let source = row.hand.source.components(separatedBy: ";")[0]
    let names = ["red", "green", "blue"]
    for (vi, variant) in source.components(separatedBy: "|").enumerated() {
      if vi > 0 { pieces.append(TextPiece(text: "-or-", color: ink, scale: 0.8)) }
      for token in variant.split(separator: " ") {
        let parts = token.split(separator: "/")
        let body = String(parts[0])
        if parts.count == 2, let k = ["x": 0, "y": 1, "z": 2][String(parts[1])] {
          let color = (options.grayscale || options.retyped) ? ink : style.palette[k]
          pieces.append(TextPiece(text: body, color: color))
          if options.retyped { pieces.append(TextPiece(text: "[\(names[k])]", color: ink, scale: 0.8)) }
        } else {
          pieces.append(TextPiece(text: body, color: ink))
        }
      }
    }
    if let marker = row.marker { pieces.append(TextPiece(text: marker, color: ink, scale: 1)) }
    return pieces
  }

  static func isConcealed(_ row: RowSpec) -> Bool { row.hand.line.concealed }

  static func tailStrings(_ row: RowSpec) -> (x: String?, pts: String?) {
    let x: String? = row.ambiguity == .missingExposure ? nil : (isConcealed(row) ? "C" : "X")
    let pts: String? = row.ambiguity == .missingPoints ? nil : String(row.hand.line.points)
    return (x, pts)
  }

  static func width(_ pieces: [TextPiece], canvas: Canvas, size: CGFloat, space: CGFloat) -> CGFloat {
    var w: CGFloat = 0
    for (i, p) in pieces.enumerated() {
      w += canvas.width(p.text, size: size * p.scale)
      if i < pieces.count - 1 && p.text != pieces[i + 1].text.prefix(0) {
        w += (pieces[i + 1].text == "*" || pieces[i + 1].text == "**") ? 0 : space
      }
    }
    return w
  }

  static func fitScale(
    page: PageSpec, style: LayoutStyle, canvas: Canvas, colW: CGFloat, options: RenderOptions
  ) -> CGFloat {
    var scale: CGFloat = 1
    for section in page.sections {
      for row in section.rows {
        let pieces = patternPieces(row, style: style, options: options)
        let w = width(pieces, canvas: canvas, size: style.size, space: style.size * 0.5)
        let available: CGFloat
        switch style.tail {
        case .gridXPts: available = colW * 0.48
        case .mergedXPts: available = colW * 0.55
        case .ruleXPts: available = colW * 0.66
        case .leadingPtsX: available = colW * 0.72
        case .trailingPtsX: available = colW * 0.7
        case .leaderThenXPts: available = colW - 85
        }
        if w > available { scale = min(scale, available / w) }
      }
    }
    return max(scale, 0.62)
  }

  static func drawHeader(
    _ header: [String], canvas: Canvas, x: CGFloat, colW: CGFloat, y: CGFloat, body: CGFloat, color: CGColor
  ) {
    let xs: [CGFloat] = [0, 0.5, 0.78, 0.9]
    for (i, text) in header.enumerated() {
      canvas.draw(text, x: x + colW * xs[i] + 3, baseline: y + body, size: body * 0.8, color: color)
    }
  }

  // MARK: Row

  @discardableResult
  static func drawRow(
    _ row: RowSpec, number: Int, style: LayoutStyle, canvas: Canvas, x: CGFloat, colW: CGFloat,
    y: CGFloat, body: CGFloat, options: RenderOptions
  ) -> CGFloat {
    let ctx = canvas.ctx
    let ink = rgb(0.08, 0.08, 0.1)
    let base = y + body * 1.15
    let space = body * 0.5
    var pieces = patternPieces(row, style: style, options: options)

    // Ambiguity that changes the printed text.
    if row.ambiguity == .zeroLetter {
      if let i = pieces.firstIndex(where: { $0.text.contains("0") }) {
        pieces[i].text = pieces[i].text.replacingOccurrences(of: "0", with: "O")
      } else if let i = pieces.firstIndex(where: { $0.text.contains("1") }) {
        pieces[i].text = pieces[i].text.replacingOccurrences(of: "1", with: "I")
      }
    }
    var faintIndex: Int?
    if row.ambiguity == .faint, options.visualAmbiguity {
      let candidates = pieces.indices.filter { pieces[$0].text.first?.isNumber == true }
      faintIndex = candidates.isEmpty ? nil : candidates[candidates.count / 2]
    }
    let tail = tailStrings(row)
    let exposureColor = style.redExposure && !options.grayscale ? style.palette[0] : ink
    let note = RowDecor.noteText(row.hand)

    var px = x
    if style.rowNumbers > 0 {
      let label = style.rowNumbers == 1 ? "\(number)." : "\(number))"
      canvas.draw(label, x: px, baseline: base, size: body * 0.9, color: ink)
      px += body * 2.2
    }

    switch style.tail {
    case .leadingPtsX:
      let lead = [tail.pts, tail.x].compactMap { $0 }.joined(separator: " ")
      canvas.draw(lead, x: px, baseline: base, size: body, color: exposureColor)
      px += body * 4.6
    case .gridXPts:
      ctx.setStrokeColor(rgb(0.6, 0.6, 0.6))
      ctx.setLineWidth(0.6)
      ctx.stroke(CGRect(x: x, y: y - 2, width: colW, height: body * 1.6 + 5))
      for f in [0.48, 0.76, 0.88] as [CGFloat] {
        ctx.move(to: CGPoint(x: x + colW * f, y: y - 2))
        ctx.addLine(to: CGPoint(x: x + colW * f, y: y + body * 1.6 + 3))
      }
      ctx.strokePath()
      px += 4
    default: break
    }

    // Pattern.
    let patternStart = px
    var patternEnd = px
    for (i, piece) in pieces.enumerated() {
      let size = body * piece.scale
      var color = piece.color
      if i == faintIndex { color = piece.color.copy(alpha: 0.13) ?? piece.color }
      let w = canvas.draw(piece.text, x: px, baseline: base, size: size, color: color)
      px += w
      patternEnd = px
      let next = i + 1 < pieces.count ? pieces[i + 1].text : ""
      if next != "*" && next != "**" { px += space }
    }
    var height = body * 1.6

    if row.ambiguity == .blot, options.visualAmbiguity {
      let mid = patternStart + (patternEnd - patternStart) * 0.5
      ctx.setFillColor(rgb(0.42, 0.40, 0.38))
      ctx.fillEllipse(in: CGRect(x: mid - body * 1.8, y: y - 1, width: body * 3.6, height: body * 1.7))
    }

    // Notes and tail.
    switch style.tail {
    case .leaderThenXPts:
      var nx = patternEnd + space
      if style.notes == .inlineParen {
        nx += canvas.draw("(\(note))", x: nx, baseline: base, size: body * 0.8, color: ink) + space
      }
      let tailText = [tail.x, tail.pts].compactMap { $0 }
      let tw = canvas.width(tailText.joined(separator: " "), size: body) + 2
      let tx = x + colW - tw
      var dot = nx
      let dotW = canvas.width(".", size: body * 0.8)
      while dot + dotW < tx - 3 {
        canvas.draw(".", x: dot, baseline: base, size: body * 0.8, color: ink)
        dot += dotW * 1.8
      }
      var cx = tx
      if let xs = tail.x { cx += canvas.draw(xs, x: cx, baseline: base, size: body, color: exposureColor) + space * 0.6 }
      if let pts = tail.pts { canvas.draw(pts, x: cx, baseline: base, size: body, color: ink) }
    case .gridXPts:
      canvas.draw("(\(note))", x: x + colW * 0.48 + 5, baseline: base, size: body * 0.75, color: ink)
      if let xs = tail.x { canvas.draw(xs, x: x + colW * 0.78, baseline: base, size: body, color: ink) }
      if let pts = tail.pts { canvas.draw(pts, x: x + colW * 0.9, baseline: base, size: body, color: ink) }
    case .trailingPtsX:
      let tailText = [tail.pts, tail.x].compactMap { $0 }.joined(separator: "  ")
      let tw = canvas.width(tailText, size: body)
      canvas.draw(tailText, x: x + colW - tw, baseline: base, size: body, color: ink)
      if style.notes == .belowParen {
        canvas.draw("(\(note))", x: x + 3, baseline: base + body * 1.1, size: body * 0.78, color: ink)
        height += body * 1.0
      }
    case .mergedXPts:
      let merged = [tail.x, tail.pts].compactMap { $0 }.joined()
      canvas.draw(merged, x: x + colW * 0.62, baseline: base, size: body, color: ink)
      if style.notes == .rightColumn {
        canvas.draw(note.lowercased(), x: x + colW * 0.78, baseline: base, size: body * 0.85, color: ink)
      }
    case .ruleXPts:
      ctx.setStrokeColor(rgb(0.4, 0.4, 0.4))
      ctx.setLineWidth(0.8)
      ctx.move(to: CGPoint(x: x + colW * 0.74, y: y - 2))
      ctx.addLine(to: CGPoint(x: x + colW * 0.74, y: y + body * 1.6))
      ctx.strokePath()
      if let xs = tail.x { canvas.draw(xs, x: x + colW * 0.78, baseline: base, size: body, color: ink) }
      if let pts = tail.pts { canvas.draw(pts, x: x + colW * 0.88, baseline: base, size: body, color: ink) }
    case .leadingPtsX: break
    }
    return height
  }
}
