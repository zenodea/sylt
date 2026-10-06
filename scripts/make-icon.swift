// Renders the app icon: a dark tile with the island pill, a live dot and audio bars.
// Usage: swift scripts/make-icon.swift  → Resources/AppIcon.icns, docs/assets/icon.png
import AppKit

func draw(size s: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let inset = s * 0.045
    let tileRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: s * 0.22, yRadius: s * 0.22)
    // Night sky: deep blue falling to near-black, with an aurora of blue and violet
    // glowing up behind the island and a vignette at the corners.
    NSGradient(colors: [NSColor(red: 0.13, green: 0.19, blue: 0.36, alpha: 1), NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)])!
        .draw(in: tile, angle: -70)
    ctx.saveGState()
    tile.addClip()
    let space = CGColorSpaceCreateDeviceRGB()
    let aurora = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 0.42, green: 0.55, blue: 1, alpha: 0.55).cgColor,
        NSColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 0.22).cgColor,
        NSColor.clear.cgColor,
    ] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(aurora, startCenter: CGPoint(x: s * 0.5, y: s * 0.72), startRadius: 0, endCenter: CGPoint(x: s * 0.5, y: s * 0.72), endRadius: s * 0.62, options: [])
    let vignette = CGGradient(colorsSpace: space, colors: [NSColor.clear.cgColor, NSColor.black.withAlphaComponent(0.45).cgColor] as CFArray, locations: [0.55, 1])!
    ctx.drawRadialGradient(vignette, startCenter: CGPoint(x: s * 0.5, y: s * 0.5), startRadius: 0, endCenter: CGPoint(x: s * 0.5, y: s * 0.5), endRadius: s * 0.78, options: [])
    // faint stars
    srand48(7)
    for _ in 0..<34 {
        let x = inset + CGFloat(drand48()) * (s - inset * 2), y = inset + CGFloat(drand48()) * (s - inset * 2)
        let r = s * (0.002 + CGFloat(drand48()) * 0.005)
        NSColor.white.withAlphaComponent(0.2 + CGFloat(drand48()) * 0.45).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
    }
    ctx.restoreGState()
    // the island: a black pill with a deep shadow and a hairline of light along its rim
    let w = s * 0.74, h = s * 0.26
    let pill = NSRect(x: (s - w) / 2, y: s - inset - h - s * 0.15, width: w, height: h)
    let pillPath = NSBezierPath(roundedRect: pill, xRadius: h * 0.44, yRadius: h * 0.44)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.03), blur: s * 0.11, color: NSColor.black.withAlphaComponent(0.75).cgColor)
    NSColor.black.setFill()
    pillPath.fill()
    ctx.restoreGState()
    ctx.saveGState()
    pillPath.addClip()
    let rim = CGGradient(colorsSpace: space, colors: [NSColor.white.withAlphaComponent(0.16).cgColor, NSColor.clear.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: 0, y: pill.maxY), end: CGPoint(x: 0, y: pill.maxY - h * 0.35), options: [])
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.09).setStroke()
    pillPath.lineWidth = max(1, s * 0.004)
    pillPath.stroke()
    // live dot with its halo
    let dot = h * 0.24
    let dotRect = NSRect(x: pill.minX + h * 0.44, y: pill.midY - dot / 2, width: dot, height: dot)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: dot * 0.9, color: NSColor(red: 0.29, green: 0.87, blue: 0.5, alpha: 0.9).cgColor)
    NSColor(red: 0.36, green: 0.9, blue: 0.56, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()
    ctx.restoreGState()
    // album art, then the audio bars, as the island shows a track
    let art = h * 0.5
    let barsStart = pill.maxX - h * 0.44 - (h * 0.11 * 4 + h * 0.09 * 3)
    let artRect = NSRect(x: barsStart - h * 0.22 - art, y: pill.midY - art / 2, width: art, height: art)
    let artPath = NSBezierPath(roundedRect: artRect, xRadius: art * 0.26, yRadius: art * 0.26)
    NSGradient(colors: [NSColor(red: 0.98, green: 0.55, blue: 0.62, alpha: 1), NSColor(red: 0.98, green: 0.72, blue: 0.4, alpha: 1)])!.draw(in: artPath, angle: -50)
    let colors = [NSColor(red: 0.96, green: 0.68, blue: 1, alpha: 1), NSColor(red: 0.76, green: 0.54, blue: 1, alpha: 1),
                  NSColor(red: 0.52, green: 0.58, blue: 0.99, alpha: 1), NSColor(red: 0.42, green: 0.92, blue: 0.99, alpha: 1)]
    let heights: [CGFloat] = [0.42, 0.72, 0.55, 0.85]
    let barW = h * 0.11, gap = h * 0.09
    var x = pill.maxX - h * 0.44 - (barW * 4 + gap * 3)
    for (i, color) in colors.enumerated() {
        let bh = h * heights[i]
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: barW * 1.2, color: color.withAlphaComponent(0.7).cgColor)
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: pill.midY - bh / 2, width: barW, height: bh), xRadius: barW / 2, yRadius: barW / 2).fill()
        ctx.restoreGState()
        x += barW + gap
    }
    // a sheet of glass over the tile: a soft highlight along the top
    ctx.saveGState()
    tile.addClip()
    let sheen = CGGradient(colorsSpace: space, colors: [NSColor.white.withAlphaComponent(0.14).cgColor, NSColor.clear.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: tileRect.maxY), end: CGPoint(x: 0, y: tileRect.maxY - s * 0.22), options: [])
    ctx.restoreGState()
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
