import CoreGraphics
import Foundation
import MahjongCore

/// Builds the original annotated corpus. Everything here is generated from a seed; no real card is used.
public enum CorpusBuilder {
  public static let seed: UInt64 = 20_261_110

  static let plan: [(Split, SourceFormat, String)] = [
    (.dev, .phonePhoto, "L1"), (.dev, .phonePhoto, "L2"), (.dev, .phonePhoto, "L3"), (.dev, .phonePhoto, "L4"),
    (.dev, .textPDF, "L1"), (.dev, .textPDF, "L2"), (.dev, .textPDF, "L3"),
    (.dev, .imagePDF, "L1"), (.dev, .imagePDF, "L3"), (.dev, .imagePDF, "L4"),
    (.dev, .screenshot, "L2"), (.dev, .screenshot, "L3"), (.dev, .screenshot, "L4"),
    (.dev, .grayscale, "L1"), (.dev, .grayscale, "L2"), (.dev, .grayscale, "L4"),
    (.dev, .screenPhoto, "L1"), (.dev, .screenPhoto, "L3"),
    (.dev, .retyped, "L2"), (.dev, .retyped, "L4"),
    (.heldOut, .phonePhoto, "L5"), (.heldOut, .phonePhoto, "L6"),
    (.heldOut, .textPDF, "L5"), (.heldOut, .imagePDF, "L6"),
    (.heldOut, .screenshot, "L5"), (.heldOut, .screenshot, "L6"),
    (.heldOut, .grayscale, "L5"), (.heldOut, .screenPhoto, "L6"),
    (.heldOut, .retyped, "L5"), (.heldOut, .retyped, "L6"),
  ]

  static func style(_ id: String) -> LayoutStyle { Layouts.all[id]! }

  static let plainTitles = [
    "Even Numbers", "Winds and Dragons", "Year Hands", "Odd Numbers", "Pairs and Singles",
    "Threes and Sixes", "Flowers", "Kongs", "Mixed Suits", "Big Sets",
  ]

  public static func buildPages() -> [PageSpec] {
    var used = Set<String>()
    var pools: [Split: [PoolHand]] = [:]
    pools[.dev] = HandPool.generate(count: 420, seed: 101, excluding: &used)
    pools[.heldOut] = HandPool.generate(count: 220, seed: 202, excluding: &used)
    var cursors: [Split: [ShiftScope: [PoolHand]]] = [:]
    for split in [Split.dev, .heldOut] {
      var byScope: [ShiftScope: [PoolHand]] = [:]
      for hand in pools[split]! { byScope[hand.shift, default: []].append(hand) }
      cursors[split] = byScope
    }
    func take(_ split: Split, _ scope: ShiftScope) -> PoolHand {
      cursors[split]![scope]!.removeFirst()
    }

    var rng = SeededRng(seed: seed)
    var pages: [PageSpec] = []
    var counters: [Split: Int] = [.dev: 0, .heldOut: 0]
    let ambiguityCycle: [Ambiguity] = [
      .missingPoints, .zeroLetter, .blot, .missingExposure, .faint, .zeroLetter,
    ]
    var ambiguityIndex = 0

    for (split, format, layout) in plan {
      counters[split]! += 1
      let n = counters[split]!
      let id = (split == .dev ? "dev-" : "held-") + String(format: "%02d", n)
      var rowCounter = 0
      func makeRow(_ hand: PoolHand, marker: String? = nil) -> RowSpec {
        rowCounter += 1
        return RowSpec(hand: hand, ambiguity: nil, marker: marker, id: "\(id)-r\(rowCounter)")
      }
      var titles = plainTitles.shuffled(using: &rng)
      var sections: [SectionSpec] = []
      var footnotes: [(marker: String, text: String)] = []
      sections.append(
        SectionSpec(
          title: titles.removeFirst(), sectionShift: nil,
          rows: (0..<2).map { _ in makeRow(take(split, .none)) }))
      switch n % 3 {
      case 0:
        sections.append(
          SectionSpec(
            title: rng.chance(0.5) ? "Consecutive Run" : "Any Like Numbers", sectionShift: .consecutive,
            rows: (0..<2).map { _ in makeRow(take(split, .consecutive)) }))
      case 1:
        sections.append(
          SectionSpec(
            title: titles.removeFirst(), sectionShift: nil,
            rows: [makeRow(take(split, .none)), makeRow(take(split, .consecutive), marker: "*")]))
        footnotes.append(("*", "Numbers may be any consecutive or like set; the example is shown."))
      default:
        sections.append(
          SectionSpec(
            title: titles.removeFirst(), sectionShift: nil,
            rows: [makeRow(take(split, .parity), marker: "**"), makeRow(take(split, .none))]))
        footnotes.append(("**", "Numbers may shift by an even step; odd stays odd and even stays even."))
      }
      sections.append(
        SectionSpec(
          title: titles.removeFirst(), sectionShift: nil,
          rows: (0..<(rng.chance(0.5) ? 2 : 1)).map { _ in makeRow(take(split, .none)) }))

      if style(layout).columns >= 2 {
        sections.append(
          SectionSpec(
            title: titles.removeFirst(), sectionShift: nil,
            rows: (0..<2).map { _ in makeRow(take(split, .none)) }))
      }
      // Deliberately ambiguous rows: one per page, two on every other dev page.
      let wanted = (split == .dev && n % 2 == 0) ? 2 : 1
      var assigned = 0
      for kindShift in 0..<(ambiguityCycle.count * 2) where assigned < wanted {
        var kind = ambiguityCycle[(ambiguityIndex + kindShift) % ambiguityCycle.count]
        if format == .textPDF && (kind == .blot || kind == .faint) { kind = .missingPoints }
        // Only plain rows (no marker, not section-scoped) become ambiguous.
        var eligible: [(Int, Int)] = []
        for (si, section) in sections.enumerated() where section.sectionShift == nil {
          for (ri, row) in section.rows.enumerated() where row.marker == nil && row.ambiguity == nil {
            let body = row.hand.source.components(separatedBy: ";")[0]
            if kind == .zeroLetter && !body.contains("0") && !body.contains("1") { continue }
            eligible.append((si, ri))
          }
        }
        guard let (si, ri) = eligible.first(where: { _ in rng.chance(0.4) }) ?? eligible.first else { continue }
        sections[si].rows[ri].ambiguity = kind
        assigned += 1
        ambiguityIndex += 1
      }
      pages.append(
        PageSpec(id: id, split: split, format: format, layout: layout, sections: sections, footnotes: footnotes))
    }
    return pages
  }

  // MARK: Writing

  public static func build(into root: URL) throws -> Manifest {
    let fm = FileManager.default
    for sub in ["dev", "held-out", "poor/dev", "poor/held-out"] {
      try fm.createDirectory(at: root.appendingPathComponent(sub), withIntermediateDirectories: true)
    }
    let pages = buildPages()
    var manifestPages: [ManifestPage] = []
    var rng = SeededRng(seed: seed ^ 0xABCD)
    for page in pages {
      let style = Layouts.all[page.layout]!
      let name = "\(page.id)-\(page.format.rawValue)-\(page.layout).\(page.format.fileExtension)"
      let url = root.appendingPathComponent(page.split.rawValue).appendingPathComponent(name)
      try writeSource(page, style: style, to: url, rng: &rng)
      let rows = page.sections.flatMap(\.rows).map { row -> ManifestRow in
        // Section-scoped shift is part of the truth even though the row itself carries no mark.
        ManifestRow(
          id: row.id, kind: row.ambiguity == nil ? .readable : .ambiguous, line: row.hand.source,
          ambiguity: row.ambiguity)
      }
      manifestPages.append(
        ManifestPage(
          id: page.id, split: page.split, format: page.format, layout: page.layout,
          file: "\(page.split.rawValue)/\(name)", rows: rows))
    }
    let poor = try buildPoor(pages: pages, root: root)
    let manifest = Manifest(version: 1, seed: seed, pages: manifestPages, poorSources: poor)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
    return manifest
  }

  static func writeSource(_ page: PageSpec, style: LayoutStyle, to url: URL, rng: inout SeededRng) throws {
    var options = RenderOptions()
    let size = PageRenderer.pageSize(style)
    switch page.format {
    case .textPDF:
      options.visualAmbiguity = false
      Imaging.writeTextPDF(page, style: style, options: options, to: url)
    case .imagePDF:
      options.paper = rgb(0.98, 0.98, 0.97)
      let image = Imaging.renderPage(page, style: style, options: options, scale: 2.4)
      let scanned = Imaging.scannerize(image, seed: rng.next(), mono: false, skewDegrees: 0.5)
      Imaging.writeImagePDF(scanned, size: size, to: url)
    case .screenshot:
      Imaging.write(Imaging.screenshot(Imaging.renderPage(page, style: style, options: options, scale: 2)), to: url)
    case .retyped:
      options.retyped = true
      Imaging.write(Imaging.screenshot(Imaging.renderPage(page, style: style, options: options, scale: 2)), to: url)
    case .grayscale:
      options.grayscale = true
      options.paper = rgb(0.97, 0.97, 0.97)
      let image = Imaging.renderPage(page, style: style, options: options, scale: 2.4)
      Imaging.write(Imaging.scannerize(image, seed: rng.next(), mono: true, skewDegrees: 0.6), to: url)
    case .phonePhoto:
      options.paper = rgb(0.86, 0.84, 0.80)
      let image = Imaging.renderPage(page, style: style, options: options, scale: 2.6)
      var params = Imaging.PhotoParams(seed: rng.next())
      params.rotationDegrees = Double.random(in: -5...5, using: &rng)
      params.keystone = Double.random(in: 0.015...0.04, using: &rng)
      params.blur = Double.random(in: 0.7...1.2, using: &rng)
      params.exposureEV = Double.random(in: -0.3...0.2, using: &rng)
      params.shadow = Double.random(in: 0.12...0.3, using: &rng)
      Imaging.write(Imaging.photoize(image, params: params), to: url, jpegQuality: 0.85)
    case .screenPhoto:
      options.paper = rgb(0.90, 0.90, 0.90)
      let image = Imaging.renderPage(page, style: style, options: options, scale: 2.2)
      var params = Imaging.PhotoParams(seed: rng.next())
      params.rotationDegrees = Double.random(in: -3...3, using: &rng)
      params.keystone = 0.02
      params.blur = 1.3
      params.moire = true
      params.shadow = 0.1
      Imaging.write(Imaging.photoize(image, params: params), to: url, jpegQuality: 0.85)
    }
  }

  static func buildPoor(pages: [PageSpec], root: URL) throws -> [ManifestPoor] {
    var out: [ManifestPoor] = []
    var rng = SeededRng(seed: seed ^ 0x5151)
    for split in [Split.dev, .heldOut] {
      let sources = pages.filter { $0.split == split && $0.format != .textPDF && $0.format != .grayscale }
      var index = 0
      for kind in PoorKind.allCases {
        for copy in 0..<2 {
          let page = sources[(index * 3 + copy) % sources.count]
          index += 1
          var options = RenderOptions()
          options.paper = rgb(0.86, 0.84, 0.80)
          let style = Layouts.all[page.layout]!
          let image = Imaging.renderPage(page, style: style, options: options, scale: 2.6)
          var params = Imaging.PhotoParams(seed: rng.next())
          params.rotationDegrees = Double.random(in: -4...4, using: &rng)
          var shown: CGImage? = image
          switch kind {
          case .heavyBlur: params.blur = 16
          case .veryDark: params.exposureEV = -3.4; params.shadow = 0.4
          case .largeGlare: params.glare = true
          case .cutOff: params.cutOff = 0.62
          case .notACard:
            shown = copy == 0 ? nil : proseImage()
          }
          let file = "poor/\(split.rawValue)/\(page.split.rawValue)-poor-\(kind.rawValue)-\(copy + 1).jpg"
          if kind == .notACard && copy == 0 { params.showPage = false }
          let picture = Imaging.photoize(shown, params: params)
          Imaging.write(picture, to: root.appendingPathComponent(file), jpegQuality: 0.85)
          out.append(
            ManifestPoor(
              id: "\(split.rawValue)-\(kind.rawValue)-\(copy + 1)", split: split, kind: kind,
              derivedFrom: page.id, file: file))
        }
      }
    }
    return out
  }

  /// An ordinary page of prose, to check that "not a card" is noticed.
  static func proseImage() -> CGImage {
    let ctx = Imaging.bitmap(width: 1530, height: 1980)
    ctx.translateBy(x: 0, y: 1980)
    ctx.scaleBy(x: 1, y: -1)
    ctx.scaleBy(x: 2.5, y: 2.5)
    ctx.setFillColor(rgb(0.97, 0.97, 0.97))
    ctx.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
    let canvas = Canvas(ctx: ctx, fontName: "Georgia")
    let text = [
      "The garden was quiet in the early morning, and the grass was still wet with dew.",
      "She carried the basket along the path, stopping now and then to look at the beans.",
      "By noon the shade under the old pear tree was the only cool place left to sit.",
      "Later they would walk down to the river and watch the boats go slowly by.",
    ]
    var y: CGFloat = 80
    for _ in 0..<12 {
      for line in text {
        canvas.draw(line, x: 50, baseline: y, size: 11, color: rgb(0.1, 0.1, 0.1))
        y += 20
      }
      y += 12
    }
    return ctx.makeImage()!
  }
}
