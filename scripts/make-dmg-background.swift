import AppKit

let size = NSSize(width: 700, height: 510)
let image = NSImage(size: size)
image.lockFocus()

NSGradient(starting: NSColor(red: 0.97, green: 0.98, blue: 1, alpha: 1),
           ending: NSColor(red: 0.89, green: 0.94, blue: 1, alpha: 1))!
    .draw(in: NSRect(origin: .zero, size: size), angle: -90)

func text(_ value: String, top: CGFloat, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    (value as NSString).draw(in: NSRect(x: 20, y: size.height - top - 36, width: 660, height: 36), withAttributes: attributes)
}

let ink = NSColor(red: 0.11, green: 0.20, blue: 0.36, alpha: 1)
let secondary = NSColor(red: 0.32, green: 0.40, blue: 0.53, alpha: 1)
text("LidKeep", top: 28, font: .systemFont(ofSize: 32, weight: .bold), color: ink)
text("合上 MacBook，让工作继续。", top: 76, font: .systemFont(ofSize: 16, weight: .medium), color: secondary)
text("Close your MacBook. Keep your work running.", top: 100, font: .systemFont(ofSize: 14), color: secondary)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 307, y: 275))
arrow.line(to: NSPoint(x: 393, y: 275))
arrow.move(to: NSPoint(x: 376, y: 292))
arrow.line(to: NSPoint(x: 393, y: 275))
arrow.line(to: NSPoint(x: 376, y: 258))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(red: 0.21, green: 0.43, blue: 0.82, alpha: 1).setStroke()
arrow.stroke()

text("拖到「应用程序」即可安装", top: 329, font: .systemFont(ofSize: 19, weight: .semibold), color: ink)
text("Drag LidKeep into Applications to install", top: 360, font: .systemFont(ofSize: 15), color: secondary)

let separator = NSBezierPath()
separator.move(to: NSPoint(x: 40, y: 105))
separator.line(to: NSPoint(x: 660, y: 105))
NSColor(red: 0.78, green: 0.84, blue: 0.93, alpha: 1).setStroke()
separator.lineWidth = 1
separator.stroke()

if CommandLine.arguments.contains("--notarized") {
    text("从「应用程序」打开 LidKeep", top: 421, font: .systemFont(ofSize: 14, weight: .medium), color: ink)
    text("Open LidKeep from Applications", top: 451, font: .systemFont(ofSize: 13), color: secondary)
} else {
    text("首次被拦截：系统设置 → 隐私与安全性 → 仍要打开", top: 421,
         font: .systemFont(ofSize: 14, weight: .medium), color: ink)
    text("If blocked: System Settings → Privacy & Security → Open Anyway", top: 451,
         font: .systemFont(ofSize: 13), color: secondary)
}
image.unlockFocus()

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1400, pixelsHigh: 1020,
                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
