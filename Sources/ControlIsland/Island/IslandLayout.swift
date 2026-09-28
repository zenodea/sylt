import CoreGraphics

struct IslandLayout: Equatable {
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 32
    var showsArtwork = false
    var showsAgents = false
    var showsAudioBars = false
    var showsMediaCard = false
    var agentRows = 0

    static let expandedWidth: CGFloat = 560
    static let expandedBaseHeight: CGFloat = 52
    static let emptyExpandedHeight: CGFloat = 36
    static let mediaCardHeight: CGFloat = 112
    static let agentRowHeight: CGFloat = 30
    static let agentHeaderHeight: CGFloat = 30
    static let maxAgentRows = 3
    static let hudHeight: CGFloat = 76
    static let compactHUDWing: CGFloat = 96
    static let wingPadding: CGFloat = 10
    static let hitMargin: CGFloat = 6

    var artworkSize: CGFloat { notchHeight - 12 }
    var compactWingWidth: CGFloat { Self.compactHUDWing - 14 }

    var wingWidth: CGFloat {
        let left: [CGFloat] = [showsAgents ? 34 : 0]
        let right: [CGFloat] = [showsArtwork ? artworkSize : 0, showsAudioBars ? 16 : 0]
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
        case .hud(let kind) where kind.isCompact:
            CGSize(width: notchWidth + Self.compactHUDWing * 2, height: notchHeight + 2)
        case .hud:
            CGSize(width: closedWidth + 180, height: Self.hudHeight)
        case .expanded:
            CGSize(width: Self.expandedWidth, height: expandedHeight)
        }
    }

    /// Island frame in canvas coordinates (top-left origin), grown by the hit margin.
    func hitFrame(for mode: IslandMode) -> CGRect {
        let island = size(for: mode)
        return CGRect(
            x: (canvasSize.width - island.width) / 2 - Self.hitMargin,
            y: 0,
            width: island.width + Self.hitMargin * 2,
            height: island.height + Self.hitMargin
        )
    }

    private static func contentWidth(_ items: [CGFloat]) -> CGFloat {
        let visible = items.filter { $0 > 0 }
        guard !visible.isEmpty else { return 0 }
        return visible.reduce(0, +) + CGFloat(visible.count - 1) * 8
    }
}
