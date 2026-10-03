import CoreGraphics

struct IslandLayout: Equatable {
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 32
    var showsArtwork = false
    var showsAudioBars = false
    var showsMediaCard = false
    var showsCalendar = false
    var showsNextEvent = false
    var privacyDots = 0
    var showsFocus = false
    var showsHeadphones = false
    var pluginLeft: [CGFloat] = []
    var pluginRight: [CGFloat] = []
    var pluginSections: [CGFloat] = []

    static let expandedWidth: CGFloat = 440
    static let expandedBaseHeight: CGFloat = 46
    static let emptyExpandedHeight: CGFloat = 36
    static let mediaCardHeight: CGFloat = 138
    static let hudHeight: CGFloat = 76
    static let eventRowHeight: CGFloat = 34
    static let sectionGap: CGFloat = 10
    /// The notification card's extra width.
    static let cardWings: CGFloat = 196
    static let hudRowHeight: CGFloat = 18
    static let wingPadding: CGFloat = 6
    static let hitMargin: CGFloat = 6
    /// Wing content sits this close to the notch, with `wingEdge` left at the island's outer end.
    static let notchGap: CGFloat = 4
    static let wingEdge: CGFloat = 8
    static let hoverGrowth = CGSize(width: 14, height: 6)

    var artworkSize: CGFloat { notchHeight - 12 }
    var isFullscreen = false

    /// Each closed wing fits its own content; an empty wing is zero.
    var leftWing: CGFloat {
        Self.wing([showsCalendar ? 52 : 0] + pluginLeft)
    }

    var rightWing: CGFloat {
        Self.wing([
            CGFloat(privacyDots) * 10, showsFocus ? 14 : 0, showsHeadphones ? 40 : 0,
            showsArtwork ? artworkSize : 0, showsAudioBars ? AudioBars.width : 0,
        ] + pluginRight)
    }

    var closedWidth: CGFloat { notchWidth + leftWing + rightWing }

    private static func wing(_ items: [CGFloat]) -> CGFloat {
        let content = contentWidth(items)
        return content == 0 ? 0 : content + wingPadding * 2
    }

    /// Heights of the expanded sections that currently have something to show.
    var expandedSections: [CGFloat] {
        var sections: [CGFloat] = []
        if showsMediaCard { sections.append(Self.mediaCardHeight) }
        if showsNextEvent { sections.append(Self.eventRowHeight) }
        sections += pluginSections.filter { $0 > 0 }
        return sections
    }

    var expandedHeight: CGFloat {
        let sections = expandedSections
        guard !sections.isEmpty else { return Self.expandedBaseHeight + Self.emptyExpandedHeight }
        return Self.expandedBaseHeight + sections.reduce(0, +) + CGFloat(sections.count - 1) * Self.sectionGap
    }

    var canvasSize: CGSize {
        let tallest = Self.mediaCardHeight + Self.eventRowHeight
            + 6 * (PluginSection.headerHeight + CGFloat(PluginSection.maxRows) * PluginSection.detailRowHeight + PluginSection.filesHeight + PluginSection.buttonsHeight + Self.sectionGap)
        // Wide enough that a one-sided HUD plus a full closed wing never reaches the window's edge.
        return CGSize(width: Self.expandedWidth + 500, height: Self.expandedBaseHeight + tallest + 80)
    }

    /// Island frame in canvas coordinates (top-left origin), grown by the hit margin.
    func hitFrame(for mode: IslandMode, hovering: Bool) -> CGRect {
        let island = frame(for: mode, hovering: hovering)
        return CGRect(
            x: (canvasSize.width - island.size.width) / 2 + island.centerOffset - Self.hitMargin,
            y: 0,
            width: island.size.width + Self.hitMargin * 2,
            height: island.size.height + Self.hitMargin
        )
    }

    /// Hovering swells every mode except the expanded panel by the same amount.
    func frame(for mode: IslandMode, hovering: Bool) -> IslandFrame {
        var frame = restingFrame(for: mode)
        if hovering, mode != .expanded {
            frame.size.width += Self.hoverGrowth.width
            frame.size.height += Self.hoverGrowth.height
        }
        return frame
    }

    private func restingFrame(for mode: IslandMode) -> IslandFrame {
        switch mode {
        case .closed:
            IslandFrame(size: CGSize(width: closedWidth, height: notchHeight), centerOffset: (rightWing - leftWing) / 2)
        case .locked:
            compact(leading: LockedView.leadingWing, trailing: LockedView.timeWing)
        case .hud(let kind):
            switch kind.style {
            case .compact:
                compact(leading: wingWidths(for: mode).leading, trailing: wingWidths(for: mode).trailing)
            case .twoRow:
                IslandFrame(size: CGSize(width: closedWidth, height: notchHeight + Self.hudRowHeight + 6), centerOffset: (rightWing - leftWing) / 2)
            case .card:
                centred(CGSize(width: notchWidth + Self.cardWings, height: Self.hudHeight))
            }
        case .expanded:
            centred(CGSize(width: Self.expandedWidth, height: expandedHeight))
        }
    }

    /// A wing a HUD doesn't claim keeps its closed width.
    func wingWidths(for mode: IslandMode) -> (leading: CGFloat, trailing: CGFloat) {
        if case .hud(let kind) = mode, case .compact(let leading, let trailing) = kind.style {
            return (leading ?? leftWing, trailing ?? rightWing)
        }
        return (leftWing, rightWing)
    }

    private func centred(_ size: CGSize) -> IslandFrame {
        IslandFrame(size: size, centerOffset: 0)
    }

    private func compact(leading: CGFloat, trailing: CGFloat) -> IslandFrame {
        IslandFrame(
            size: CGSize(width: notchWidth + leading + trailing, height: notchHeight + 2),
            centerOffset: (trailing - leading) / 2
        )
    }

    private static func contentWidth(_ items: [CGFloat]) -> CGFloat {
        let visible = items.filter { $0 > 0 }
        guard !visible.isEmpty else { return 0 }
        return visible.reduce(0, +) + CGFloat(visible.count - 1) * 8
    }
}
