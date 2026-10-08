import SwiftUI

/// Places subviews left to right and wraps to a new row when the proposed width runs out.
struct FlowLayout: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6

  private func arrange(subviews: Subviews, maxWidth: CGFloat) -> (positions: [CGPoint], size: CGSize) {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > maxWidth {
        x = 0
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      usedWidth = max(usedWidth, x + size.width)
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return (positions, CGSize(width: usedWidth, height: subviews.isEmpty ? 0 : y + rowHeight))
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = arrange(subviews: subviews, maxWidth: bounds.width)
    for (index, subview) in subviews.enumerated() {
      subview.place(
        at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
        anchor: .topLeading, proposal: .unspecified)
    }
  }
}
