import CoreGraphics
import CoreText
import Foundation
import MahjongCore

public enum NoteMode { case inlineParen, belowParen, rightColumn, none }
public enum TailMode { case leaderThenXPts, gridXPts, leadingPtsX, mergedXPts, ruleXPts, trailingPtsX }

/// A printed layout. Layouts are original designs; none imitates a publisher.
public struct LayoutStyle {
  public var id: String
  public var landscape: Bool
  public var columns: Int
  public var fontName: String
  public var size: CGFloat
  public var palette: [CGColor]
  public var notes: NoteMode
  public var tail: TailMode
  public var rowNumbers: Int  // 0 none, 1 "1.", 2 "1)"
  public var grid: Bool
  public var header: [String]?
  public var titleBar: Bool
  public var rowGap: CGFloat
  public var redExposure: Bool
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
  CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, 1])!
}

public enum Layouts {
  static let paletteA = [rgb(0.85, 0.08, 0.08), rgb(0.05, 0.55, 0.2), rgb(0.1, 0.25, 0.85)]
  static let paletteB = [rgb(0.78, 0.05, 0.55), rgb(0.0, 0.55, 0.6), rgb(0.92, 0.5, 0.0)]

  public static let all: [String: LayoutStyle] = [
    "L1": LayoutStyle(
      id: "L1", landscape: true, columns: 3, fontName: "Helvetica-Bold", size: 9.5, palette: paletteA,
      notes: .inlineParen, tail: .leaderThenXPts, rowNumbers: 0, grid: false, header: nil,
      titleBar: false, rowGap: 6, redExposure: true),
    "L2": LayoutStyle(
      id: "L2", landscape: false, columns: 1, fontName: "Menlo-Bold", size: 12, palette: paletteA,
      notes: .inlineParen, tail: .gridXPts, rowNumbers: 0, grid: true,
      header: ["Hand", "Notes", "X/C", "Pts"], titleBar: false, rowGap: 9, redExposure: false),
    "L3": LayoutStyle(
      id: "L3", landscape: false, columns: 2, fontName: "Georgia-Bold", size: 9.5, palette: paletteA,
      notes: .belowParen, tail: .trailingPtsX, rowNumbers: 0, grid: false, header: nil,
      titleBar: false, rowGap: 8, redExposure: false),
    "L4": LayoutStyle(
      id: "L4", landscape: false, columns: 1, fontName: "HelveticaNeue-Bold", size: 15,
      palette: paletteA, notes: .none, tail: .leadingPtsX, rowNumbers: 1, grid: false, header: nil,
      titleBar: false, rowGap: 12, redExposure: false),
    "L5": LayoutStyle(
      id: "L5", landscape: false, columns: 2, fontName: "AvenirNext-DemiBold", size: 9.5,
      palette: paletteB, notes: .rightColumn, tail: .mergedXPts, rowNumbers: 0, grid: false,
      header: nil, titleBar: false, rowGap: 9, redExposure: false),
    "L6": LayoutStyle(
      id: "L6", landscape: false, columns: 1, fontName: "Palatino-Bold", size: 14, palette: paletteB,
      notes: .none, tail: .ruleXPts, rowNumbers: 2, grid: false, header: nil, titleBar: true,
      rowGap: 11, redExposure: false),
  ]
}

struct TextPiece {
  var text: String
  var color: CGColor
  var scale: CGFloat = 1
}

final class Canvas {
  let ctx: CGContext
  let fontName: String
  init(ctx: CGContext, fontName: String) { self.ctx = ctx; self.fontName = fontName }

  func font(_ size: CGFloat, name: String? = nil) -> CTFont {
    CTFontCreateWithName((name ?? fontName) as CFString, size, nil)
  }

  func width(_ text: String, size: CGFloat, name: String? = nil) -> CGFloat {
    let line = makeLine(text, size: size, color: rgb(0, 0, 0), name: name)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
  }

  func makeLine(_ text: String, size: CGFloat, color: CGColor, name: String? = nil) -> CTLine {
    let attrs: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font(size, name: name),
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
  }

  /// Draws at a baseline in a top-left-origin context. Returns the advance width.
  @discardableResult
  func draw(_ text: String, x: CGFloat, baseline: CGFloat, size: CGFloat, color: CGColor, name: String? = nil)
    -> CGFloat
  {
    let line = makeLine(text, size: size, color: color, name: name)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
  }
}

enum RowDecor {
  static func suitCount(_ hand: PoolHand) -> Int {
    var vars = Set<String>()
    for variant in hand.line.variants {
      for group in variant.groups {
        switch group.tile {
        case .number(_, let ref), .matchingDragon(let ref):
          if case .variable(let v) = ref { vars.insert(v.rawValue) }
        default: break
        }
      }
    }
    return vars.count
  }

  static func noteText(_ hand: PoolHand) -> String {
    let n = suitCount(hand)
    return n == 0 ? "Winds and Dragons" : "Any \(n) Suit\(n == 1 ? "" : "s")"
  }
}
