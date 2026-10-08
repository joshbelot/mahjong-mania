import SwiftUI

/// A bamboo stalk: three rounded segments separated by two node gaps.
struct BambooShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let gap = rect.height * 0.07
    let segment = (rect.height - 2 * gap) / 3
    let radius = min(rect.width, segment) * 0.35
    for index in 0..<3 {
      let y = rect.minY + CGFloat(index) * (segment + gap)
      path.addRoundedRect(
        in: CGRect(x: rect.minX, y: y, width: rect.width, height: segment),
        cornerSize: CGSize(width: radius, height: radius))
    }
    return path
  }
}

/// A ring with an inner dot. Fill with the even-odd rule (`FillStyle(eoFill: true)`), which `DotView` does.
struct DotShape: Shape {
  func path(in rect: CGRect) -> Path {
    let side = min(rect.width, rect.height)
    let box = CGRect(
      x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    var path = Path()
    path.addEllipse(in: box)
    path.addEllipse(in: box.insetBy(dx: side * 0.17, dy: side * 0.17))
    path.addEllipse(in: box.insetBy(dx: side * 0.35, dy: side * 0.35))
    return path
  }
}

/// `DotShape` filled with the even-odd rule so the ring is hollow around the centre dot.
struct DotView: View {
  let color: Color

  var body: some View {
    DotShape().fill(color, style: FillStyle(eoFill: true))
  }
}
