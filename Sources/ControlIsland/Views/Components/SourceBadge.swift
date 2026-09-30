import AppKit
import SwiftUI

/// The icon of the app a track plays from, for the corner of its artwork.
struct SourceBadge: View {
    let bundleIdentifier: String?
    var size: CGFloat = 18

    var body: some View {
        if let icon = bundleIdentifier.flatMap(Self.icon(for:)) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .padding(1.5)
                .background(.black, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
    }

    private static var cache: [String: NSImage] = [:]

    private static func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleIdentifier] = icon
        return icon
    }
}
