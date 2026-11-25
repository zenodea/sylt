import CoreGraphics

struct IslandLayout: Equatable {
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 32
    var screenWidth: CGFloat = 1512
    var isFullscreen = false
    var showsArtwork = false
    var showsAudioBars = false
    var showsMediaCard = false
    var showsCalendar = false
    var showsNextEvent = false
    var privacyDots = 0
    var showsFocus = false
    var showsHeadphones = false
    var hasBattery = true
    var bluetoothOn = false
    var lockShowsStatus = false
    var wings = ResolvedWings()
    var pluginWidths: [String: CGFloat] = [:]
    var pluginSectionHeights: [String: CGFloat] = [:]
    var expandedPages: [[ExpandedSection]] = []
    var expandedPage = 0
    var spreadsPages = false
    var glassCards = false
    var notchDepth: CGFloat = 0
    var menuBarOverhang: CGFloat = 0
    /// Without a notch the island is a capsule the user places along any edge or in a corner.
    var hasNotch = true
    var placement = IslandPlacement.standard
    var screenSize = CGSize(width: 1512, height: 982)
    var screenInsets = ScreenInsets()

    static let expandedWidth: CGFloat = 440
    static let spreadMargin: CGFloat = 120
    static let maxColumns = 3
    static let expandedBaseHeight: CGFloat = 60
    static let emptyExpandedHeight: CGFloat = 36
    static let mediaCardHeight: CGFloat = 138
    static let hudHeight: CGFloat = 76
    static let eventRowHeight: CGFloat = 34
    static let sectionGap: CGFloat = 10
    static let glassCardInset: CGFloat = 8
    static let pageDotsHeight: CGFloat = 14
    static let cardWings: CGFloat = 196
    static let hudRowHeight: CGFloat = 18
    static let hudRowPadding: CGFloat = 6
    static let wingPadding: CGFloat = 6
    static let hitMargin: CGFloat = 6
    static let notchGap: CGFloat = 4
    static let wingEdge: CGFloat = 8
    static let partGap: CGFloat = 8
    static let hoverGrowth = CGSize(width: 14, height: 6)
    // The hardware notch is a little wider than the area macOS reports.
    static let sideOverlap: CGFloat = 6
    private static let canvasPluginSections = 6
    private static let canvasSlack: CGFloat = 80
    /// How far a floating island keeps off the screen's edge, the menu bar and the Dock.
    static let floatingGap: CGFloat = 8
    /// Above the open island's sections where there is no notch to clear.
    static let floatingHeader: CGFloat = 8
    /// The closed island's height, and the gap between its wings, on a screen without a notch.
    static let notchlessHeight: CGFloat = 30
    static let notchlessGap: CGFloat = 4
    /// A card overlay is this much wider than the notch; without one it is this wide in all.
    private static let notchlessCardBase: CGFloat = 180

    var overlap: CGFloat { isFullscreen || !hasNotch ? 0 : max(notchDepth, menuBarOverhang) }

    var anchor: IslandAnchor {
        hasNotch
            ? .notch(canvasWidth: canvasSize.width)
            : .placed(placement, screen: screenSize, insets: screenInsets, gap: Self.floatingGap)
    }

    /// Where the island of this size sits on the canvas.
    func rect(of frame: IslandFrame) -> CGRect { anchor.rect(for: frame) }

    /// The space above the open island's sections: the notch, or a margin.
    var expandedHeader: CGFloat { hasNotch ? notchHeight : Self.floatingHeader }

    private var expandedBase: CGFloat { Self.expandedBaseHeight - (notchHeight - expandedHeader) }

    var artworkSize: CGFloat { notchHeight - 12 }

    var leftWing: CGFloat { wing(wings.left) }
    var rightWing: CGFloat { wing(wings.right) }

    func visibleItems(_ items: [WingItem]) -> [WingItem] {
        items.filter { widths(of: $0).contains { $0 > 0 } }
    }

    private func wing(_ items: [WingItem]) -> CGFloat {
        guard let last = spans(of: items).last else { return 0 }
        return last.end + Self.wingPadding * 2
    }

    private func spans(of items: [WingItem]) -> [(item: WingItem, start: CGFloat, end: CGFloat)] {
        let visible = visibleItems(items)
        var cursor: CGFloat = 0
        return visible.enumerated().map { index, item in
            if index > 0 { cursor += wings.gap(after: visible[index - 1]).width }
            let start = cursor
            cursor += Self.contentWidth(widths(of: item))
            return (item, start, cursor)
        }
    }

    func widths(of item: WingItem) -> [CGFloat] {
        switch item {
        case .calendar: [showsCalendar ? CalendarBadge.width : 0]
        case .privacy: [CGFloat(privacyDots) * PrivacyDots.dotWidth]
        case .focus: [showsFocus ? ClosedWing.focusWidth : 0]
        case .headphones: [showsHeadphones ? HeadphonesBadge.width : 0]
        case .music: [showsArtwork ? artworkSize : 0, showsAudioBars ? AudioBars.width : 0]
        case .wifi: [WiFiBadge.width]
        case .bluetooth: [bluetoothOn ? BluetoothBadge.width : 0]
        case .volume: [VolumeBadge.width]
        case .battery: [hasBattery ? BatteryBadge.width : 0]
        case .plugin(let id): [pluginWidths[id] ?? 0]
        }
    }

    var closedWidth: CGFloat { notchWidth + Self.sideOverlap * 2 + leftWing + rightWing }

    var availableSections: [ExpandedSection] {
        var sections: [ExpandedSection] = []
        sections.append(.media)
        if showsNextEvent { sections.append(.event) }
        sections += pluginSectionHeights.filter { $0.value > 0 }.keys.sorted().map(ExpandedSection.plugin)
        return sections
    }

    var columns: Int {
        guard spreadsPages else { return 1 }
        let fit = Int((screenWidth - Self.spreadMargin * 2) / Self.expandedWidth)
        return max(1, min(Self.maxColumns, fit, expandedPages.count))
    }

    var spreadCount: Int {
        (expandedPages.count + columns - 1) / columns
    }

    var currentSpread: Int {
        min(max(expandedPage, 0), max(0, expandedPages.count - 1)) / columns
    }

    var currentSpreadPages: [[ExpandedSection]] {
        let start = currentSpread * columns
        guard start < expandedPages.count else { return [] }
        return Array(expandedPages[start ..< min(start + columns, expandedPages.count)])
    }

    var expandedWidth: CGFloat {
        Self.expandedWidth * CGFloat(columns)
    }

    func height(of section: ExpandedSection) -> CGFloat {
        switch section {
        case .media: Self.mediaCardHeight
        case .event: Self.eventRowHeight
        case .plugin(let id): pluginSectionHeights[id].map { $0 + (glassCards ? Self.glassCardInset * 2 : 0) } ?? 0
        }
    }

    var expandedHeight: CGFloat {
        guard let tallest = expandedPages.map(stackHeight(of:)).max() else { return expandedBase + Self.emptyExpandedHeight }
        return expandedBase + tallest + dotsHeight
    }

    func spareHeight(on page: [ExpandedSection]) -> CGFloat {
        max(0, expandedHeight - expandedBase - dotsHeight - stackHeight(of: page))
    }

    static func share(_ spare: CGFloat, among needs: [String: CGFloat]) -> [String: CGFloat] {
        var remaining = spare
        var open = needs.filter { $0.value > 0 }.sorted { ($0.value, $0.key) < ($1.value, $1.key) }
        var granted: [String: CGFloat] = [:]
        while !open.isEmpty, remaining > 0 {
            let fair = remaining / CGFloat(open.count)
            let (id, need) = open.removeFirst()
            let given = min(need, fair)
            granted[id] = given
            remaining -= given
        }
        return granted
    }

    private var dotsHeight: CGFloat { spreadCount > 1 ? Self.pageDotsHeight : 0 }

    private func stackHeight(of page: [ExpandedSection]) -> CGFloat {
        page.map(height(of:)).reduce(0, +) + CGFloat(max(0, page.count - 1)) * Self.sectionGap
    }

    var canvasSize: CGSize {
        // Placed anywhere on the screen, the island needs all of it.
        guard hasNotch else { return screenSize }
        let pluginSection = PluginSection.headerHeight + CGFloat(PluginSection.maxRows) * PluginSection.detailRowHeight + PluginSection.filesHeight + PluginSection.buttonsHeight + Self.sectionGap + Self.glassCardInset * 2
        let tallest = Self.mediaCardHeight + Self.eventRowHeight + CGFloat(Self.canvasPluginSections) * pluginSection
        return CGSize(width: screenWidth, height: Self.expandedBaseHeight + tallest + Self.canvasSlack)
    }

    func hitFrame(for mode: IslandMode, hovering: Bool) -> CGRect {
        // A margin on every side, cut off where the island meets the edge of the screen.
        rect(of: frame(for: mode, hovering: hovering))
            .insetBy(dx: -Self.hitMargin, dy: -Self.hitMargin)
            .intersection(CGRect(origin: .zero, size: canvasSize))
    }

    /// Where the pointer is put when the island opens: just inside its top, under the notch if there is one.
    var expandedHome: CGPoint {
        let open = rect(of: frame(for: .expanded, hovering: false))
        return CGPoint(x: open.midX, y: open.minY + expandedHeader + Self.homeDepth)
    }

    private static let homeDepth: CGFloat = 16

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
            wingsFrame(leading: leftWing, trailing: rightWing)
        case .locked:
            wingsFrame(leading: LockedView.leadingWing + (lockShowsStatus ? leftWing : 0), trailing: LockedView.timeWing + (lockShowsStatus ? rightWing : 0))
        case .hud(let kind):
            switch kind.style {
            case .compact:
                wingsFrame(wingWidths(for: mode))
            case .twoRow:
                wingsFrame(wingWidths(for: mode), below: Self.hudRowHeight + Self.hudRowPadding)
            case .card:
                IslandFrame(size: CGSize(width: (hasNotch ? notchWidth : Self.notchlessCardBase) + Self.cardWings, height: Self.hudHeight), centerOffset: 0)
            }
        case .expanded:
            IslandFrame(size: CGSize(width: expandedWidth, height: expandedHeight), centerOffset: 0)
        }
    }

    func wingWidths(for mode: IslandMode) -> (leading: CGFloat, trailing: CGFloat) {
        if case .hud(let kind) = mode, case .compact(let leading, let trailing) = kind.style {
            return (leading ?? leftWing, trailing ?? rightWing)
        }
        if case .hud(.notification) = mode {
            return (max(leftWing, HUDKind.wing(artworkSize)), rightWing)
        }
        return (leftWing, rightWing)
    }

    private func wingsFrame(_ widths: (leading: CGFloat, trailing: CGFloat), below extraHeight: CGFloat = 0) -> IslandFrame {
        wingsFrame(leading: widths.leading, trailing: widths.trailing, below: extraHeight)
    }

    private func wingsFrame(leading: CGFloat, trailing: CGFloat, below extraHeight: CGFloat = 0) -> IslandFrame {
        IslandFrame(
            size: CGSize(width: notchWidth + Self.sideOverlap * 2 + leading + trailing, height: notchHeight + overlap + extraHeight),
            centerOffset: (trailing - leading) / 2
        )
    }

    func item(at x: CGFloat, hovering: Bool = false) -> WingItem? {
        // The wings sit centred in the island, which may have grown on hover from wherever it's attached.
        let island = rect(of: frame(for: .closed, hovering: hovering))
        let start = island.midX - closedWidth / 2
        let notchLeft = start + leftWing
        let notchRight = notchLeft + notchWidth + Self.sideOverlap * 2
        let centre = (notchLeft + notchRight) / 2
        let side = x < centre ? wings.left : wings.right
        let origin = x < centre ? start + Self.wingPadding : notchRight + Self.wingPadding
        let local = x - origin
        return spans(of: side).first { local >= $0.start - Self.partGap && local <= $0.end + Self.partGap }?.item
    }

    func page(for item: WingItem) -> Int? {
        let section: ExpandedSection
        switch item {
        case .music: section = .media
        case .calendar: section = .event
        case .plugin(let id): section = .plugin(id)
        default: return nil
        }
        return expandedPages.firstIndex { $0.contains(section) }
    }

    private static func contentWidth(_ items: [CGFloat]) -> CGFloat {
        let visible = items.filter { $0 > 0 }
        guard !visible.isEmpty else { return 0 }
        return visible.reduce(0, +) + CGFloat(visible.count - 1) * partGap
    }
}
