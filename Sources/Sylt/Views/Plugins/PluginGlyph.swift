import AppKit
import SwiftUI

struct PluginGlyph: View {
    let symbol: String?
    let image: String?
    var tint: String? = nil
    var size: CGFloat = 14

    var body: some View {
        if let image, let nsImage = Self.load(image) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        } else if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.85, weight: .semibold))
                .symbolRenderingMode(tint == nil ? .multicolor : .monochrome)
                .foregroundStyle(Color(tint: tint))
                .frame(width: size, height: size)
        }
    }

    @MainActor
    private static func load(_ reference: String) -> NSImage? {
        guard let colon = reference.firstIndex(of: ":") else { return nil }
        let value = String(reference[reference.index(after: colon)...])
        switch reference[..<colon] {
        case "app": return AppIcons.icon(for: value)
        case "file": return NSImage(contentsOfFile: value)
        case "icon": return NSWorkspace.shared.icon(forFile: value)
        default: return nil
        }
    }
}
