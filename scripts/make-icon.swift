// Renders the app icon: a dark tile with the island pill, a live dot and audio bars.
// Usage: swift scripts/make-icon.swift  → Resources/AppIcon.icns, docs/assets/icon.png
import AppKit

func draw(size s: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let inset = s * 0.045
    let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2), xRadius: s * 0.22, yRadius: s * 0.22)
    let gradient = NSGradient(colors: [NSColor(red: 0.14, green: 0.20, blue: 0.36, alpha: 1), NSColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)])!
    gradient.draw(in: tile, angle: -60)
    // faint stars
    srand48(7)
    for _ in 0..<26 {
        let x = inset + CGFloat(drand48()) * (s - inset * 2), y = inset + CGFloat(drand48()) * (s - inset * 2)
        let r = s * (0.002 + CGFloat(drand48()) * 0.004)
        NSColor.white.withAlphaComponent(0.25 + CGFloat(drand48()) * 0.4).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
    }
    // the island: a black pill hanging from the top like the notch, with a glow
    let w = s * 0.66, h = s * 0.26
    let pill = NSRect(x: (s - w) / 2, y: s - inset - h - s * 0.14, width: w, height: h)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.08, color: NSColor.black.withAlphaComponent(0.7).cgColor)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: pill, xRadius: h * 0.42, yRadius: h * 0.42).fill()
    ctx.restoreGState()
    // live dot
    let dot = h * 0.26
    NSColor(red: 0.29, green: 0.87, blue: 0.5, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: pill.minX + h * 0.42, y: pill.midY - dot / 2, width: dot, height: dot)).fill()
    // audio bars
    let colors = [NSColor(red: 0.94, green: 0.67, blue: 0.99, alpha: 1), NSColor(red: 0.75, green: 0.52, blue: 0.99, alpha: 1),
                  NSColor(red: 0.51, green: 0.55, blue: 0.97, alpha: 1), NSColor(red: 0.40, green: 0.91, blue: 0.98, alpha: 1)]
    let heights: [CGFloat] = [0.42, 0.72, 0.55, 0.85]
    let barW = h * 0.11, gap = h * 0.09
    var x = pill.maxX - h * 0.42 - (barW * 4 + gap * 3)
    for (i, color) in colors.enumerated() {
        let bh = h * heights[i]
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: pill.midY - bh / 2, width: barW, height: bh), xRadius: barW / 2, yRadius: barW / 2).fill()
        x += barW + gap
    }
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, scale: CGFloat = 1) -> Data {
    let size = image.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(draw(size: CGFloat(base))).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(draw(size: CGFloat(base)), scale: 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! FileManager.default.createDirectory(atPath: "docs/assets", withIntermediateDirectories: true)
try! png(draw(size: 256), scale: 2).write(to: URL(fileURLWithPath: "docs/assets/icon.png"))
print("iconset written")
