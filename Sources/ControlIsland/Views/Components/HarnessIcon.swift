import SwiftUI

struct HarnessIcon: View {
    let harness: Harness
    var size: CGFloat = 18

    var body: some View {
        if let icon = Self.applicationIcon(for: harness) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else if harness == .pi {
            PiLogo()
                .padding(size * 0.18)
                .frame(width: size, height: size)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        } else {
            Text(harness.glyph)
                .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        }
    }

    private var tint: Color {
        Color(red: harness.tint.red, green: harness.tint.green, blue: harness.tint.blue)
    }

    private static var cache: [Harness: NSImage?] = [:]

    private static func applicationIcon(for harness: Harness) -> NSImage? {
        if let cached = cache[harness] { return cached }
        let url = harness.applicationBundleIdentifiers.lazy
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .first
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[harness] = icon
        return icon
    }
}
