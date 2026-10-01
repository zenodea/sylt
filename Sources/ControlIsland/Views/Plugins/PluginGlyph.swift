import AppKit
import SwiftUI

/// A plugin's glyph: an SF Symbol, an app icon (`app:bundle.id`) or an image file (`file:/path`).
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
                .foregroundStyle(Color(tint: tint))
                .frame(width: size, height: size)
        }
    }

    @MainActor
    private static func load(_ reference: String) -> NSImage? {
        if reference.hasPrefix("app:") { return AppIcons.icon(for: String(reference.dropFirst(4))) }
        if reference.hasPrefix("file:") { return NSImage(contentsOfFile: String(reference.dropFirst(5))) }
        if reference.hasPrefix("icon:") { return NSWorkspace.shared.icon(forFile: String(reference.dropFirst(5))) }
        return nil
    }
}
