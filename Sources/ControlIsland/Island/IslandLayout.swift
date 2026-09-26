import CoreGraphics

struct IslandLayout: Equatable {
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 32
    var showsArtwork = false
    var showsAgents = false
    var showsAudioBars = false

    static let expandedWidth: CGFloat = 520
    static let expandedBaseHeight: CGFloat = 230
    static let mediaCardHeight: CGFloat = 100
    static let hudHeight: CGFloat = 76
    static let wingPadding: CGFloat = 10

    var artworkSize: CGFloat { notchHeight - 12 }

    var wingWidth: CGFloat {
        let left: [CGFloat] = [showsArtwork ? artworkSize : 0, showsAgents ? 26 : 0]
        let right: [CGFloat] = [showsAudioBars ? 16 : 0]
        let widest = max(Self.contentWidth(left), Self.contentWidth(right))
        return widest == 0 ? 0 : widest + Self.wingPadding * 2
    }

    var closedWidth: CGFloat { notchWidth + wingWidth * 2 }

    var canvasSize: CGSize {
        CGSize(
            width: Self.expandedWidth + 160,
            height: Self.expandedBaseHeight + Self.mediaCardHeight + 80
        )
    }

    func size(for mode: IslandMode, expandedHeight: CGFloat) -> CGSize {
        switch mode {
        case .closed:
            CGSize(width: closedWidth, height: notchHeight)
        case .peek:
            CGSize(width: closedWidth + 18, height: notchHeight + 7)
        case .hud(let kind):
            CGSize(width: closedWidth + (kind.isWide ? 180 : 110), height: Self.hudHeight)
        case .expanded:
            CGSize(width: Self.expandedWidth, height: expandedHeight)
        }
    }

    private static func contentWidth(_ items: [CGFloat]) -> CGFloat {
        let visible = items.filter { $0 > 0 }
        guard !visible.isEmpty else { return 0 }
        return visible.reduce(0, +) + CGFloat(visible.count - 1) * 8
    }
}
