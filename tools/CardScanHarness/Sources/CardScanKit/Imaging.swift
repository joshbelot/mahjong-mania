import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum Imaging {
  public static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  static func bitmap(width: Int, height: Int) -> CGContext {
    CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  }

  /// Draws a page to a bitmap at `scale` pixels per point.
  public static func renderPage(
    _ page: PageSpec, style: LayoutStyle, options: RenderOptions, scale: CGFloat
  ) -> CGImage {
    let size = PageRenderer.pageSize(style)
    let ctx = bitmap(width: Int(size.width * scale), height: Int(size.height * scale))
    ctx.translateBy(x: 0, y: size.height * scale)
    ctx.scaleBy(x: scale, y: -scale)
    PageRenderer.draw(page: page, style: style, options: options, ctx: ctx)
    return ctx.makeImage()!
  }

  /// Vector PDF with a real text layer.
  public static func writeTextPDF(
    _ page: PageSpec, style: LayoutStyle, options: RenderOptions, to url: URL
  ) {
    var box = CGRect(origin: .zero, size: PageRenderer.pageSize(style))
    let info = [kCGPDFContextTitle as String: "Sample card"] as CFDictionary
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, info) else { return }
    ctx.beginPDFPage(nil)
    ctx.translateBy(x: 0, y: box.height)
    ctx.scaleBy(x: 1, y: -1)
    PageRenderer.draw(page: page, style: style, options: options, ctx: ctx)
    ctx.endPDFPage()
    ctx.closePDF()
  }

  /// A PDF that only contains a picture of the page: no text layer.
  public static func writeImagePDF(_ image: CGImage, size: CGSize, to url: URL) {
    var box = CGRect(origin: .zero, size: size)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
    ctx.beginPDFPage(nil)
    ctx.draw(image, in: box)
    ctx.endPDFPage()
    ctx.closePDF()
  }

  public static func write(_ image: CGImage, to url: URL, jpegQuality: Double? = nil) {
    let type: UTType = jpegQuality == nil ? .png : .jpeg
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
    else { return }
    var props: [CFString: Any] = [:]
    if let q = jpegQuality { props[kCGImageDestinationLossyCompressionQuality] = q }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    CGImageDestinationFinalize(dest)
  }

  // MARK: Photo simulation

  public struct PhotoParams {
    public var seed: UInt64
    public var canvas = CGSize(width: 2800, height: 2100)
    public var rotationDegrees: Double = 3
    public var keystone: Double = 0.03
    public var blur: Double = 0.9
    public var noise: Double = 0.05
    public var exposureEV: Double = -0.4
    public var warm = true
    public var shadow: Double = 0.18
    public var glare = false
    /// Fraction of the page pushed outside the frame on the left.
    public var cutOff: Double = 0
    public var pageHeightFraction: Double = 0.86
    public var moire = false
    public var showPage = true
    public init(seed: UInt64) { self.seed = seed }
  }

  static func ci(_ image: CGImage) -> CIImage { CIImage(cgImage: image) }

  static func background(size: CGSize, rng: inout SeededRng) -> CIImage {
    let ctx = bitmap(width: Int(size.width), height: Int(size.height))
    ctx.setFillColor(rgb(0.36, 0.26, 0.18))
    ctx.fill(CGRect(origin: .zero, size: size))
    for _ in 0..<2500 {
      let shade = CGFloat.random(in: 0.15...0.5, using: &rng)
      ctx.setStrokeColor(CGColor(red: shade + 0.1, green: shade * 0.7, blue: shade * 0.45, alpha: 0.25))
      ctx.setLineWidth(CGFloat.random(in: 1...6, using: &rng))
      let y = CGFloat.random(in: 0...size.height, using: &rng)
      let x = CGFloat.random(in: -200...size.width, using: &rng)
      ctx.move(to: CGPoint(x: x, y: y))
      ctx.addLine(to: CGPoint(x: x + CGFloat.random(in: 100...700, using: &rng), y: y + CGFloat.random(in: -8...8, using: &rng)))
      ctx.strokePath()
    }
    return CIImage(cgImage: ctx.makeImage()!)
  }

  public static func photoize(_ page: CGImage?, params: PhotoParams) -> CGImage {
    var rng = SeededRng(seed: params.seed)
    let size = params.canvas
    let rect = CGRect(origin: .zero, size: size)
    var composite = background(size: size, rng: &rng)

    if let page, params.showPage {
      let pw = CGFloat(page.width)
      let ph = CGFloat(page.height)
      let scale = min(size.width * 0.9 / pw, size.height * params.pageHeightFraction / ph)
      let w = pw * scale
      let h = ph * scale
      let cx = size.width / 2 - CGFloat(params.cutOff) * w
      let cy = size.height / 2
      let theta = CGFloat(params.rotationDegrees) * .pi / 180
      func corner(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
        let jx = CGFloat.random(in: -1...1, using: &rng) * w * CGFloat(params.keystone)
        let jy = CGFloat.random(in: -1...1, using: &rng) * h * CGFloat(params.keystone)
        let x = dx * w / 2 + jx
        let y = dy * h / 2 + jy
        return CGPoint(x: cx + x * cos(theta) - y * sin(theta), y: cy + x * sin(theta) + y * cos(theta))
      }
      let tl = corner(-1, 1), tr = corner(1, 1), bl = corner(-1, -1), br = corner(1, -1)
      var source = ci(page)
      if params.moire { source = addMoire(source, rng: &rng) }
      let transform = CIFilter.perspectiveTransform()
      transform.inputImage = source
      transform.topLeft = tl
      transform.topRight = tr
      transform.bottomLeft = bl
      transform.bottomRight = br
      let warped = transform.outputImage!
      // Soft shadow under the paper.
      let shadow = CIFilter.gaussianBlur()
      shadow.inputImage = warped.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.5),
      ]).transformed(by: CGAffineTransform(translationX: 14, y: -14))
      shadow.radius = 18
      composite = shadow.outputImage!.composited(over: composite)
      composite = warped.composited(over: composite)
    }

    // Uneven light: a diagonal gradient multiplied in, then a warm cast.
    let gradient = CIFilter.linearGradient()
    gradient.point0 = CGPoint(x: 0, y: size.height)
    gradient.point1 = CGPoint(x: size.width, y: 0)
    let lo = 1 - params.shadow
    gradient.color0 = CIColor(red: 1, green: 1, blue: 1)
    gradient.color1 = CIColor(red: lo, green: lo, blue: lo)
    composite = gradient.outputImage!.cropped(to: rect).applyingFilter(
      "CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: composite])

    if params.glare {
      let radial = CIFilter.radialGradient()
      radial.center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
      radial.radius0 = Float(size.height * 0.22)
      radial.radius1 = Float(size.height * 0.46)
      radial.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
      radial.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
      composite = radial.outputImage!.cropped(to: rect).composited(over: composite)
    }
    if params.warm {
      let temp = CIFilter.temperatureAndTint()
      temp.inputImage = composite
      temp.neutral = CIVector(x: 6500, y: 0)
      temp.targetNeutral = CIVector(x: 5000, y: 0)
      composite = temp.outputImage!
    }
    if params.exposureEV != 0 {
      let exposure = CIFilter.exposureAdjust()
      exposure.inputImage = composite
      exposure.ev = Float(params.exposureEV)
      composite = exposure.outputImage!
    }
    if params.blur > 0 {
      let blur = CIFilter.gaussianBlur()
      blur.inputImage = composite.clampedToExtent()
      blur.radius = Float(params.blur)
      composite = blur.outputImage!.cropped(to: rect)
    }
    if params.noise > 0 {
      let noise = CIFilter.randomGenerator().outputImage!.cropped(to: rect).applyingFilter(
        "CIColorMatrix", parameters: [
          "inputRVector": CIVector(x: CGFloat(params.noise), y: 0, z: 0, w: 0),
          "inputGVector": CIVector(x: 0, y: CGFloat(params.noise), z: 0, w: 0),
          "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(params.noise), w: 0),
          "inputBiasVector": CIVector(x: -CGFloat(params.noise) / 2, y: -CGFloat(params.noise) / 2, z: -CGFloat(params.noise) / 2, w: 0),
        ])
      composite = noise.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: composite])
    }
    return ciContext.createCGImage(composite.cropped(to: rect), from: rect)!
  }

  /// Fine diagonal stripes that beat against the text, like the pixel grid of a screen.
  static func addMoire(_ image: CIImage, rng: inout SeededRng) -> CIImage {
    let extent = image.extent
    let stripes = CIFilter.stripesGenerator()
    stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.10)
    stripes.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
    stripes.width = 2.2
    stripes.sharpness = 0.8
    let rotated = stripes.outputImage!
      .transformed(by: CGAffineTransform(rotationAngle: 0.05))
      .cropped(to: extent)
    return rotated.composited(over: image)
  }

  /// Slight scanner skew and grain for scanned/printed sources.
  public static func scannerize(_ image: CGImage, seed: UInt64, mono: Bool, skewDegrees: Double) -> CGImage {
    var out = ci(image)
    let extent = out.extent
    if mono {
      let mono = CIFilter.photoEffectMono()
      mono.inputImage = out
      out = mono.outputImage!
      let controls = CIFilter.colorControls()
      controls.inputImage = out
      controls.contrast = 1.25
      controls.brightness = 0.03
      out = controls.outputImage!
    }
    let rotate = CGAffineTransform(translationX: extent.midX, y: extent.midY)
      .rotated(by: CGFloat(skewDegrees) * .pi / 180)
      .translatedBy(x: -extent.midX, y: -extent.midY)
    out = out.transformed(by: rotate).composited(over: CIImage(color: CIColor(red: 0.95, green: 0.95, blue: 0.95)).cropped(to: extent)).cropped(to: extent)
    let noise = CIFilter.randomGenerator().outputImage!.cropped(to: extent).applyingFilter(
      "CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.04, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.04, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 0.04, w: 0),
        "inputBiasVector": CIVector(x: -0.02, y: -0.02, z: -0.02, w: 0),
      ])
    out = noise.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: out])
    return ciContext.createCGImage(out, from: extent)!
  }

  /// A phone screenshot: the page scaled to the phone width under a small status bar.
  public static func screenshot(_ page: CGImage) -> CGImage {
    let width = 1170
    let scale = CGFloat(width) / CGFloat(page.width)
    let h = Int(CGFloat(page.height) * scale)
    let bar = 110
    let ctx = bitmap(width: width, height: h + bar)
    ctx.setFillColor(rgb(1, 1, 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: h + bar))
    ctx.setFillColor(rgb(0.96, 0.96, 0.97))
    ctx.fill(CGRect(x: 0, y: h, width: width, height: bar))
    ctx.interpolationQuality = .high
    ctx.draw(page, in: CGRect(x: 0, y: 0, width: width, height: h))
    ctx.saveGState()
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: "9:41", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica-Bold" as CFString, 40, nil),
      ]))
    ctx.textPosition = CGPoint(x: 70, y: CGFloat(h) + 40)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return ctx.makeImage()!
  }
}
