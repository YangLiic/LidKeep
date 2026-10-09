import AppKit
import Foundation

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ context: CGContext, path: CGPath, colors: [CGColor], locations: [CGFloat], from: CGPoint, to: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let ramp = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(ramp, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

func drawIcon(_ context: CGContext) {
    let tile = rounded(CGRect(x: 64, y: 64, width: 896, height: 896), radius: 196)
    gradient(context, path: tile, colors: [color(0x559AFF), color(0x2868E5), color(0x123DA1)], locations: [0, 0.52, 1],
             from: CGPoint(x: 64, y: 64), to: CGPoint(x: 736, y: 960))

    context.saveGState()
    context.addPath(tile)
    context.clip()
    let highlight = CGMutablePath()
    highlight.move(to: CGPoint(x: 64, y: 64))
    highlight.addLine(to: CGPoint(x: 960, y: 64))
    highlight.addLine(to: CGPoint(x: 960, y: 190))
    highlight.addCurve(to: CGPoint(x: 64, y: 422), control1: CGPoint(x: 698, y: 131), control2: CGPoint(x: 365, y: 168))
    highlight.closeSubpath()
    context.addPath(highlight)
    context.setFillColor(color(0xFFFFFF, alpha: 0.08))
    context.fillPath()
    context.restoreGState()

    context.addPath(rounded(CGRect(x: 65, y: 65, width: 894, height: 894), radius: 195))
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.16))
    context.setLineWidth(2)
    context.strokePath()

    context.saveGState()
    context.setShadow(offset: .zero, blur: 36, color: color(0x062366, alpha: 0.3))
    context.setFillColor(color(0x062366, alpha: 0.12))
    context.fillEllipse(in: CGRect(x: 196, y: 745, width: 632, height: 36))
    context.restoreGState()

    let metal = [color(0xFFFFFF), color(0xC4D4EF)]
    gradient(context, path: rounded(CGRect(x: 202, y: 278, width: 620, height: 386), radius: 34),
             colors: metal, locations: [0, 1], from: CGPoint(x: 512, y: 278), to: CGPoint(x: 512, y: 664))
    gradient(context, path: rounded(CGRect(x: 223, y: 301, width: 578, height: 338), radius: 18),
             colors: [color(0x244B83), color(0x10254B)], locations: [0, 1],
             from: CGPoint(x: 223, y: 301), to: CGPoint(x: 801, y: 639))
    context.addPath(rounded(CGRect(x: 470, y: 300, width: 84, height: 13), radius: 6))
    context.setFillColor(color(0xEFF5FF))
    context.fillPath()

    context.setLineWidth(12)
    context.setLineCap(.round)
    context.setStrokeColor(color(0xFFD57C))
    for ray in [(512, 365, 512, 346), (512, 575, 512, 594), (407, 470, 388, 470), (617, 470, 636, 470),
                (438, 396, 424, 382), (586, 544, 600, 558), (438, 544, 424, 558), (586, 396, 600, 382)] {
        context.move(to: CGPoint(x: ray.0, y: ray.1))
        context.addLine(to: CGPoint(x: ray.2, y: ray.3))
    }
    context.strokePath()
    gradient(context, path: CGPath(ellipseIn: CGRect(x: 447, y: 405, width: 130, height: 130), transform: nil),
             colors: [color(0xFFE49A), color(0xFFB84C)], locations: [0, 1],
             from: CGPoint(x: 512, y: 405), to: CGPoint(x: 512, y: 535))

    let base = CGMutablePath()
    base.move(to: CGPoint(x: 166, y: 684))
    base.addLine(to: CGPoint(x: 858, y: 684))
    base.addLine(to: CGPoint(x: 825, y: 731))
    base.addQuadCurve(to: CGPoint(x: 799, y: 742), control: CGPoint(x: 819, y: 742))
    base.addLine(to: CGPoint(x: 225, y: 742))
    base.addQuadCurve(to: CGPoint(x: 199, y: 731), control: CGPoint(x: 205, y: 742))
    base.closeSubpath()
    gradient(context, path: base, colors: metal, locations: [0, 1], from: CGPoint(x: 512, y: 684), to: CGPoint(x: 512, y: 742))

    let notch = CGMutablePath()
    notch.move(to: CGPoint(x: 457, y: 684))
    notch.addLine(to: CGPoint(x: 567, y: 684))
    notch.addLine(to: CGPoint(x: 567, y: 688))
    notch.addQuadCurve(to: CGPoint(x: 556, y: 699), control: CGPoint(x: 567, y: 699))
    notch.addLine(to: CGPoint(x: 468, y: 699))
    notch.addQuadCurve(to: CGPoint(x: 457, y: 688), control: CGPoint(x: 457, y: 699))
    notch.closeSubpath()
    context.addPath(notch)
    context.setFillColor(color(0x92A9CE))
    context.fillPath()
    context.move(to: CGPoint(x: 226, y: 742))
    context.addLine(to: CGPoint(x: 798, y: 742))
    context.setStrokeColor(color(0x91ACD6))
    context.setLineWidth(5)
    context.strokePath()
}

let target = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
        drawIcon(context)
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: target).appendingPathComponent(name))
    }
}
