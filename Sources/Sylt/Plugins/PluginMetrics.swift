import CoreGraphics
import SwiftUI

/// How much room plugin content takes, so wings and sections can be laid out before drawing.
extension PluginItem {
    static let glyph: CGFloat = 14
    static let gap: CGFloat = 3

    var width: CGFloat {
        var parts: [CGFloat] = []
        if symbol != nil || image != nil { parts.append(Self.glyph) }
        if let text, !text.isEmpty { parts.append(TextWidth.of(text, size: 11, monospacedDigits: true) + 1) }
        if dot != nil || (status != nil && symbol == nil && image == nil) { parts.append(7) }
        if ring != nil { parts.append(12) }
        if graph != nil { parts.append(Self.graphWidth) }
        return parts.reduce(0, +) + CGFloat(max(0, parts.count - 1)) * Self.gap
    }

    static let graphWidth: CGFloat = 26

    static func width(of items: [PluginItem], spacing: CGFloat = 8) -> CGFloat {
        let widths = items.map(\.width).filter { $0 > 0 }
        return widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * spacing
    }
}

extension PluginSection {
    static let headerHeight: CGFloat = 22
    static let rowHeight: CGFloat = 24
    static let detailRowHeight: CGFloat = 32
    static let filesHeight: CGFloat = 56
    static let buttonsHeight: CGFloat = 30
    static let maxRows = 4
    static let rowSpacing: CGFloat = 3

    var height: CGFloat {
        var height: CGFloat = Self.headerHeight + visibleRowsHeight
        if !(files ?? []).isEmpty { height += Self.filesHeight }
        if !(buttons ?? []).isEmpty { height += Self.buttonsHeight }
        return height
    }

    /// Exactly the first rows and the spacing between them: the list frame must match its
    /// content to the point, or a list that fits still scrolls and bounces.
    var visibleRowsHeight: CGFloat {
        let shown = (rows ?? []).prefix(Self.maxRows)
        return shown.reduce(0) { $0 + $1.height } + CGFloat(max(0, shown.count - 1)) * Self.rowSpacing
    }

    /// How much taller the list would be with every row showing instead of scrolling.
    var hiddenRowsHeight: CGFloat {
        (rows ?? []).dropFirst(Self.maxRows).reduce(0) { $0 + $1.height + Self.rowSpacing }
    }
}

extension PluginRow {
    var height: CGFloat { detail == nil && large != true ? PluginSection.rowHeight : PluginSection.detailRowHeight }
}

extension Color {
    /// A plugin's colour word or hex, defaulting to white.
    init(tint: String?) {
        switch tint?.lowercased() {
        case "dim": self = .white.opacity(0.6)
        case "green": self = .green
        case "orange": self = .orange
        case "red": self = .red
        case "yellow": self = .yellow
        case "blue": self = .blue
        case "indigo": self = .indigo
        case "purple": self = .purple
        case "pink": self = .pink
        case "cyan": self = .cyan
        case let hex? where hex.hasPrefix("#") && hex.count == 7:
            let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xFFFFFF
            self = Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
        default: self = .white
        }
    }
}
