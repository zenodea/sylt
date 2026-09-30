import AppKit

/// Measures rounded system text so wings can be sized to what they hold.
enum TextWidth {
    static func of(_ text: String, size: CGFloat, weight: NSFont.Weight = .semibold) -> CGFloat {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = NSFont(descriptor: descriptor, size: size) ?? base
        return ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
    }

    static func widest(_ texts: [String], size: CGFloat) -> CGFloat {
        texts.map { of($0, size: size) }.max() ?? 0
    }
}
