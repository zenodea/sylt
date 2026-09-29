import CoreGraphics

struct IslandLayout: Equatable {
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 32
    var showsArtwork = false
    var showsAgents = false
    var showsAudioBars = false
    var showsMediaCard = false
    var agentRows = 0

    static let expandedWidth: CGFloat = 440
    static let expandedBaseHeight: CGFloat = 46
    static let emptyExpandedHeight: CGFloat = 36
    static let mediaCardHeight: CGFloat = 104
    static let agentRowHeight: CGFloat = 26
    static let agentHeaderHeight: CGFloat = 26
    static let maxAgentRows = 3
    static let hudHeight: CGFloat = 76
    static let hudRowHeight: CGFloat = 18
    static let wingPadding: CGFloat = 6
    static let hitMargin: CGFloat = 6

    var artworkSize: CGFloat { notchHeight - 12 }
    var isFullscreen = false

    var wingWidth: CGFloat {
        let left: [CGFloat] = [showsAgents ? 32 : 0]
        let right: [CGFloat] = [showsArtwork ? artworkSize : 0, showsAudioBars ? 14 : 0]
        let widest = max(Self.contentWidth(left), Self.contentWidth(right))
        return widest == 0 ? 0 : widest + Self.wingPadding * 2
    }

    var closedWidth: CGFloat { notchWidth + wingWidth * 2 }

    var expandedHeight: CGFloat {
        var height = Self.expandedBaseHeight
        if showsMediaCard { height += Self.mediaCardHeight }
        if showsAgents {
            height += Self.agentHeaderHeight + CGFloat(min(max(agentRows, 1), Self.maxAgentRows)) * Self.agentRowHeight
        }
        if showsMediaCard, showsAgents { height += 12 }
        if !showsMediaCard, !showsAgents { height += Self.emptyExpandedHeight }
        return height
    }

    var canvasSize: CGSize {
        CGSize(
            width: Self.expandedWidth + 160,
            height: Self.expandedBaseHeight + Self.mediaCardHeight
                + Self.agentHeaderHeight + CGFloat(Self.maxAgentRows) * Self.agentRowHeight + 80
        )
    }

    func size(for mode: IslandMode) -> CGSize {
        switch mode {
        case .closed:
            CGSize(width: closedWidth, height: notchHeight)
        case .peek:
            CGSize(width: closedWidth + 18, height: notchHeight + 7)
        case .hud(let kind):
            switch kind.style {
            case .compact(let leading, let trailing):
                CGSize(width: notchWidth + leading + trailing, height: notchHeight + 2)
            case .twoRow(let wing):
                CGSize(width: notchWidth + wing * 2, height: notchHeight + Self.hudRowHeight + 6)
            case .card(let width):
                CGSize(width: closedWidth + width, height: Self.hudHeight)
            }
        case .expanded:
            CGSize(width: Self.expandedWidth, height: expandedHeight)
        }
    }

    /// Island frame in canvas coordinates (top-left origin), grown by the hit margin.
    func hitFrame(for mode: IslandMode) -> CGRect {
        let island = frame(for: mode)
        return CGRect(
            x: (canvasSize.width - island.size.width) / 2 + island.centerOffset - Self.hitMargin,
            y: 0,
            width: island.size.width + Self.hitMargin * 2,
            height: island.size.height + Self.hitMargin
        )
    }

    func frame(for mode: IslandMode) -> IslandFrame {
        if case .hud(let kind) = mode, case .compact(let leading, let trailing) = kind.style {
            return IslandFrame(
                size: CGSize(width: notchWidth + leading + trailing, height: notchHeight + 2),
                centerOffset: (trailing - leading) / 2
            )
        }
        return IslandFrame(size: size(for: mode), centerOffset: 0)
    }

    private static func contentWidth(_ items: [CGFloat]) -> CGFloat {
        let visible = items.filter { $0 > 0 }
        guard !visible.isEmpty else { return 0 }
        return visible.reduce(0, +) + CGFloat(visible.count - 1) * 8
    }
}
