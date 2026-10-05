import AppKit

extension NSImage {
    /// One accent per vertical slice of the image, left to right, as if the
    /// image sat behind a row of bars. Boosted so each reads on black.
    func sliceAccents(count: Int) -> [NSColor] {
        guard count > 0, let image = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let rows = 6
        var pixels = [UInt8](repeating: 0, count: count * rows * 4)
        guard let context = CGContext(
            data: &pixels, width: count, height: rows, bitsPerComponent: 8, bytesPerRow: count * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: count, height: rows))

        return (0..<count).map { column in
            var red = 0.0, green = 0.0, blue = 0.0, total = 0.0
            for row in 0..<rows {
                let index = (row * count + column) * 4
                let r = Double(pixels[index]) / 255, g = Double(pixels[index + 1]) / 255, b = Double(pixels[index + 2]) / 255
                let brightest = max(r, g, b)
                let saturation = brightest == 0 ? 0 : (brightest - min(r, g, b)) / brightest
                let weight = 0.05 + saturation * brightest
                red += r * weight
                green += g * weight
                blue += b * weight
                total += weight
            }
            return Self.readable(NSColor(red: red / total, green: green / total, blue: blue / total, alpha: 1))
        }
    }

    private static func readable(_ color: NSColor) -> NSColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(hue: hue, saturation: min(max(saturation, 0.35), 0.9), brightness: max(brightness, 0.8), alpha: 1)
    }
}
