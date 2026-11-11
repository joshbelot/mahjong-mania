import CoreGraphics
import Foundation
import MahjongCore

/// Row and column detection that does not assume any publisher's page geometry.
public struct PageReading {
  public var rows: [(row: ScanRow, context: ScanPageContext)]
  public var footnotes: [String: Shift]
}

public struct LayoutConfig {
  /// Words closer than this fraction of a text height share a line.
  public var lineTolerance = 0.65
  /// A horizontal gap larger than this many text heights splits a line into column segments.
  public var gapHeights = 1.8
  public init() {}
}

public enum LayoutAnalyzer {
  struct Word {
    var token: ScanToken
    var px: (x0: Double, x1: Double, y0: Double, y1: Double)
    var midY: Double { (px.y0 + px.y1) / 2 }
    var height: Double { px.y1 - px.y0 }
  }

  static func isTitleCase(_ text: String) -> Bool { text.contains(where: \.isLetter) }

  public static func analyze(
    words: [RawWord], inks: [ScanInk], page: Int, imageSize: CGSize, config: LayoutConfig = LayoutConfig()
  ) -> PageReading {
    let W = Double(imageSize.width), H = Double(imageSize.height)
    var list: [Word] = []
    for (i, w) in words.enumerated() {
      let token = ScanToken(text: w.text, ink: inks[i], confidence: w.confidence, rect: w.rect, exactText: w.exact)
      list.append(Word(token: token, px: (w.rect.x * W, w.rect.maxX * W, w.rect.y * H, w.rect.maxY * H)))
    }
    guard !list.isEmpty else { return PageReading(rows: [], footnotes: [:]) }
    let heights = list.map(\.height).sorted()
    let medianHeight = max(heights[heights.count / 2], 4)

    // 1. Lines.
    list.sort { $0.midY < $1.midY }
    var lines: [[Word]] = []
    var meanY: [Double] = []
    for w in list {
      if let last = lines.indices.last, abs(w.midY - meanY[last]) <= config.lineTolerance * max(w.height, medianHeight * 0.8) {
        lines[last].append(w)
        meanY[last] = lines[last].map(\.midY).reduce(0, +) / Double(lines[last].count)
      } else {
        lines.append([w]); meanY.append(w.midY)
      }
    }

    // 2. Segments within each line, then satellites merged into the nearest anchor.
    struct Segment { var words: [Word]; var x0: Double; var x1: Double; var y: Double }
    var segmentsByLine: [[Segment]] = []
    func isAnchor(_ s: Segment) -> Bool {
      let tiles = s.words.filter { isStrongTile($0.token.text) }
      return tiles.count >= 2 || tiles.contains { $0.token.text.count >= 3 }
    }
    for line in lines {
      let sorted = line.sorted { $0.px.x0 < $1.px.x0 }
      var segs: [[Word]] = []
      for w in sorted {
        if var last = segs.last, w.px.x0 - last.last!.px.x1 <= config.gapHeights * medianHeight {
          last.append(w); segs[segs.count - 1] = last
        } else { segs.append([w]) }
      }
      segmentsByLine.append(segs.map { s in
        Segment(words: s, x0: s.first!.px.x0, x1: s.last!.px.x1, y: s.map(\.midY).reduce(0, +) / Double(s.count))
      })
    }
    // Do tails (X/C and points) trail the pattern or lead it? Vote over the whole page: a line that starts
    // with a pattern is trailing; one that starts with an X/C or points segment is leading.
    var trailVotes = 0, leadVotes = 0
    for segments in segmentsByLine where segments.contains(where: isAnchor) {
      guard let first = segments.first else { continue }
      if isAnchor(first) { trailVotes += 1 }
      else if first.words.contains(where: { ScanRowInterpreter.exposureForm(ScanRowInterpreter.clean($0.token.text)) != nil }) { leadVotes += 1 }
    }
    let trailing = trailVotes >= leadVotes
    if ProcessInfo.processInfo.environment["SCAN_DEBUG"] != nil { for segs in segmentsByLine { FileHandle.standardError.write((segs.map { "[\($0.words.map { $0.token.text }.joined(separator: " ")) @\(Int($0.x0))-\(Int($0.x1))]" }.joined(separator: " ") + "\n").data(using: .utf8)!) } }
    if ProcessInfo.processInfo.environment["SCAN_DEBUG"] != nil { FileHandle.standardError.write("votes trail \(trailVotes) lead \(leadVotes)\n".data(using: .utf8)!) }
    for (li, segments) in segmentsByLine.enumerated() where segments.contains(where: isAnchor) {
      var merged = segments.filter(isAnchor)
      for s in segments where !isAnchor(s) {
        let left = merged.indices.filter { merged[$0].x1 <= s.x0 + 0.001 }.max { merged[$0].x1 < merged[$1].x1 }
        let right = merged.indices.filter { merged[$0].x0 >= s.x1 - 0.001 }.min { merged[$0].x0 < merged[$1].x0 }
        guard let best = (trailing ? (left ?? right) : (right ?? left)) else { continue }
        merged[best].words += s.words
        merged[best].x0 = min(merged[best].x0, s.x0)
        merged[best].x1 = max(merged[best].x1, s.x1)
      }
      segmentsByLine[li] = merged.sorted { $0.x0 < $1.x0 }
    }

    // 3. Rows, titles, footnotes.
    struct Item { var row: ScanRow; var x0: Double; var x1: Double; var y: Double; var hand: Bool }
    var items: [Item] = []
    for segments in segmentsByLine {
      for s in segments {
        let tokens = s.words.sorted { $0.px.x0 < $1.px.x0 }.map(\.token)
        let row = ScanRow(page: page, tokens: tokens)
        items.append(Item(row: row, x0: s.x0, x1: s.x1, y: s.y, hand: ScanRowInterpreter.looksLikeHand(row)))
      }
    }

    var footnotes: [String: Shift] = [:]
    var titles: [(text: String, x0: Double, x1: Double, y: Double)] = []
    for item in items where !item.hand {
      let texts = item.row.tokens.map(\.text)
      if ScanRowInterpreter.isFootnote(texts) || (texts.first.map { $0.hasPrefix("*") && $0.count <= 2 } ?? false && texts.count >= 3) {
        let marker = String(texts[0].map { _ in "*" })
        if let shift = ScanRowInterpreter.footnoteShift(texts.dropFirst().joined(separator: " ")) {
          footnotes[marker] = shift
        }
      } else if texts.allSatisfy({ $0.uppercased() == $0 && $0.contains(where: \.isLetter) }) {
        titles.append((texts.joined(separator: " "), item.x0, item.x1, item.y))
      }
    }

    var rows: [(ScanRow, ScanPageContext)] = []
    for item in items where item.hand {
      let mid = (item.x0 + item.x1) / 2
      var title: String?
      var bestY = -Double.infinity
      for t in titles where t.y < item.y && t.y > bestY && mid >= t.x0 - medianHeight * 3 && mid <= t.x1 + medianHeight * 30 {
        // Same column when the title's centre is within the row's column span.
        let tMid = (t.x0 + t.x1) / 2
        if abs(tMid - mid) < (item.x1 - item.x0) * 0.75 + medianHeight * 4 { title = t.text; bestY = t.y }
      }
      rows.append((item.row, ScanPageContext(footnoteShifts: footnotes, sectionTitle: title)))
    }
    return PageReading(rows: rows.map { (row: $0.0, context: $0.1) }, footnotes: footnotes)
  }

  static func isStrongTile(_ text: String) -> Bool {
    let t = ScanRowInterpreter.clean(text)
    guard !t.isEmpty, ScanRowInterpreter.isTileLike(t) else { return false }
    if ScanRowInterpreter.exposureForm(t) != nil { return false }
    // A bare 2-3 digit number could be points, so it is not strong evidence of a pattern on its own.
    return !(t.count <= 3 && ScanRowInterpreter.pointsValue(t) != nil && t.allSatisfy(\.isNumber) && Set(t).count > 1)
  }
}
