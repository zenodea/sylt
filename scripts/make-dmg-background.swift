import AppKit

let size = NSSize(width: 640, height: 420)
// scripts/dmg.sh places the icons at these centres.
let app = CGPoint(x: 180, y: 210), applications = CGPoint(x: 460, y: 210)
let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { NSColor(red: r, green: g, blue: b, alpha: a).cgColor }

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
}

func drawSky(_ ctx: CGContext) {
    let w = size.width, h = size.height, starfield = h * 0.55
    ctx.drawLinearGradient(gradient([
        (0, rgb(0.09, 0.12, 0.25)), (0.4, rgb(0.17, 0.18, 0.38)), (0.66, rgb(0.44, 0.42, 0.62)),
        (0.8, rgb(0.47, 0.44, 0.63)), (1, rgb(0.33, 0.31, 0.5)),
    ]), start: .zero, end: CGPoint(x: 0, y: h), options: [])
    ctx.saveGState()
    ctx.translateBy(x: w / 2, y: h * 0.62)
    ctx.scaleBy(x: 1.7, y: 1)
    ctx.drawRadialGradient(gradient([(0, rgb(0.55, 0.62, 1, 0.45)), (0.5, rgb(0.62, 0.42, 0.95, 0.2)), (1, rgb(0, 0, 0, 0))]),
                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: h * 0.42, options: [])
    ctx.restoreGState()
    srand48(11)
    for _ in 0..<70 {
        let x = CGFloat(drand48()) * w, y = CGFloat(drand48()) * starfield
        let r = 0.6 + CGFloat(drand48()) * 1.4
        let fade = 1 - y / starfield
        ctx.setFillColor(rgb(1, 1, 1, (0.25 + CGFloat(drand48()) * 0.55) * fade))
        ctx.fillEllipse(in: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r))
    }
}

func drawIsland(_ ctx: CGContext) {
    let w: CGFloat = 196, h: CGFloat = 38, padding: CGFloat = 18
    let pill = CGRect(x: (size.width - w) / 2, y: -h, width: w, height: h * 2)
    let path = CGPath(roundedRect: pill, cornerWidth: h * 0.55, cornerHeight: h * 0.55, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 18, color: rgb(0, 0, 0, 0.6))
    ctx.setFillColor(.black)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.setStrokeColor(rgb(1, 1, 1, 0.1))
    ctx.setLineWidth(1)
    ctx.addPath(path)
    ctx.strokePath()

    let mid = h / 2
    let dot: CGFloat = 9
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 8, color: rgb(0.29, 0.87, 0.5, 0.9))
    ctx.setFillColor(rgb(0.36, 0.9, 0.56))
    ctx.fillEllipse(in: CGRect(x: pill.minX + padding, y: mid - dot / 2, width: dot, height: dot))
    ctx.restoreGState()

    let barW: CGFloat = 4, gap: CGFloat = 3.5
    let barsStart = pill.maxX - padding - (barW * 4 + gap * 3)
    let art: CGFloat = 19
    let artRect = CGRect(x: barsStart - 9 - art, y: mid - art / 2, width: art, height: art)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: artRect, cornerWidth: 5, cornerHeight: 5, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0, rgb(0.98, 0.55, 0.62)), (1, rgb(0.98, 0.72, 0.4))]),
                           start: CGPoint(x: artRect.minX, y: artRect.minY), end: CGPoint(x: artRect.maxX, y: artRect.maxY), options: [])
    ctx.restoreGState()
    let colors = [rgb(0.96, 0.68, 1), rgb(0.76, 0.54, 1), rgb(0.52, 0.58, 0.99), rgb(0.42, 0.92, 0.99)]
    let heights: [CGFloat] = [0.42, 0.72, 0.55, 0.85]
    for (i, color) in colors.enumerated() {
        let bh = h * heights[i]
        let bar = CGRect(x: barsStart + CGFloat(i) * (barW + gap), y: mid - bh / 2, width: barW, height: bh)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 5, color: color.copy(alpha: 0.7))
        ctx.setFillColor(color)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }
}

func drawArrow(_ ctx: CGContext) {
    let clearance: CGFloat = 82, y = app.y - 4
    let start = CGPoint(x: app.x + clearance, y: y), end = CGPoint(x: applications.x - clearance, y: y)
    let control = CGPoint(x: (start.x + end.x) / 2, y: app.y - 46)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 10, color: rgb(0.75, 0.8, 1, 0.9))
    ctx.setStrokeColor(rgb(1, 1, 1, 0.9))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(4)
    ctx.setLineDash(phase: 0, lengths: [0.01, 11])
    ctx.move(to: start)
    ctx.addQuadCurve(to: end, control: control)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.setLineWidth(3.5)
    let angle = atan2(end.y - control.y, end.x - control.x)
    for side in [-1.0, 1.0] {
        let a = angle + .pi - side * 0.6
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x + cos(a) * 13, y: end.y + sin(a) * 13))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

func drawCaption() {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 6
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: font.pointSize) } ?? font
    let text = NSAttributedString(string: "Drag Sylt into Applications", attributes: [
        .font: rounded, .foregroundColor: NSColor.white.withAlphaComponent(0.92), .shadow: shadow, .paragraphStyle: paragraph,
    ])
    text.draw(in: NSRect(x: 0, y: size.height - 52, width: size.width, height: 20))
}

let background = NSImage(size: size, flipped: true) { _ in
    let ctx = NSGraphicsContext.current!.cgContext
    drawSky(ctx)
    drawArrow(ctx)
    drawIsland(ctx)
    drawCaption()
    return true
}

func png(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    background.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let folder = URL(fileURLWithPath: "build/dmg-background")
try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let low = folder.appendingPathComponent("background.png"), high = folder.appendingPathComponent("background@2x.png")
try! png(scale: 1).write(to: low)
try! png(scale: 2).write(to: high)
let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", low.path, high.path, "-out", "Resources/DMGBackground.tiff"]
try! tiffutil.run()
tiffutil.waitUntilExit()
print("Resources/DMGBackground.tiff written")
