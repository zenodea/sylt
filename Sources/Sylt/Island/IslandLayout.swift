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
    /// The locked island keeps the closed wings beside the padlock and the time.
    var lockShowsStatus = false
    /// Which items each closed wing shows, in order, and how wide each plugin's badge is.
    var wings = ResolvedWings()
    var pluginWidths: [String: CGFloat] = [:]
    var pluginSectionHeights: [String: CGFloat] = [:]
    /// The expanded view's pages, each a few sections, and which one is open.
    var expandedPages: [[ExpandedSection]] = []
    var expandedPage = 0
    /// Pages sit side by side when the screen has room, from Settings.
    var spreadsPages = false

    static let expandedWidth: CGFloat = 440
    /// Room to leave either side of a spread, so it never crowds the screen's corners.
    static let spreadMargin: CGFloat = 120
    static let maxColumns = 3
    static let expandedBaseHeight: CGFloat = 60
    static let emptyExpandedHeight: CGFloat = 36
    static let mediaCardHeight: CGFloat = 138
    static let hudHeight: CGFloat = 76
    static let eventRowHeight: CGFloat = 34
    static let sectionGap: CGFloat = 10
    static let pageDotsHeight: CGFloat = 14
    /// The notification card's extra width.
    static let cardWings: CGFloat = 196
    static let hudRowHeight: CGFloat = 18
    static let hudRowPadding: CGFloat = 6
    static let wingPadding: CGFloat = 6
    static let hitMargin: CGFloat = 6
    /// Wing content sits this close to the notch, with `wingEdge` left at the island's outer end.
    static let notchGap: CGFloat = 4
    static let wingEdge: CGFloat = 8
    /// The space between the parts of one wing item, such as artwork and audio bars.
    static let partGap: CGFloat = 8
    static let hoverGrowth = CGSize(width: 14, height: 6)
    /// The hardware notch runs a little deeper and wider than the area macOS reports; the
    /// island always covers it with room to spare, so its rounded corners begin on screen.
    /// How far the island reaches below the notch on the desktop, from Settings.
    var notchDepth: CGFloat = 0

    /// In a full-screen app the menu bar is the only thing at the top, so the island
    /// matches it exactly whatever the setting.
    var overlap: CGFloat { isFullscreen ? 0 : notchDepth }
    static let sideOverlap: CGFloat = 6
    /// The canvas leaves room for this many full plugin sections, plus some slack.
    private static let canvasPluginSections = 6
    private static let canvasSlack: CGFloat = 80

    var artworkSize: CGFloat { notchHeight - 12 }

    /// Each closed wing fits its own content; an empty wing is zero.
    var leftWing: CGFloat { wing(wings.left) }
    var rightWing: CGFloat { wing(wings.right) }

    /// The items with something to show right now, in order.
    func visibleItems(_ items: [WingItem]) -> [WingItem] {
        items.filter { widths(of: $0).contains { $0 > 0 } }
    }

    /// Content plus the gap chosen between each pair of visible neighbours.
    private func wing(_ items: [WingItem]) -> CGFloat {
        let visible = visibleItems(items)
        guard !visible.isEmpty else { return 0 }
        var total: CGFloat = 0
        for (index, item) in visible.enumerated() {
            total += Self.contentWidth(widths(of: item))
            if index > 0 { total += wings.gap(between: visible[index - 1], and: item).width }
        }
        return total + Self.wingPadding * 2
    }

    /// The widths an item takes right now, zero when it has nothing to show.
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

    /// Every section with something to show right now, in natural order.
    var availableSections: [ExpandedSection] {
        var sections: [ExpandedSection] = []
        sections.append(.media)
        if showsNextEvent { sections.append(.event) }
        sections += pluginSectionHeights.filter { $0.value > 0 }.keys.sorted().map(ExpandedSection.plugin)
        return sections
    }

    /// Pages shown side by side: as many as fit with room to spare, up to three, when spreading is on.
    var columns: Int {
        guard spreadsPages else { return 1 }
        let fit = Int((screenWidth - Self.spreadMargin * 2) / Self.expandedWidth)
        return max(1, min(Self.maxColumns, fit, expandedPages.count))
    }

    /// How many turns it takes to see every page.
    var spreadCount: Int {
        (expandedPages.count + columns - 1) / columns
    }

    var currentSpread: Int {
        min(max(expandedPage, 0), max(0, expandedPages.count - 1)) / columns
    }

    /// The pages open right now, left to right.
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
        case .plugin(let id): pluginSectionHeights[id] ?? 0
        }
    }

    /// The same on every page: the tallest page sets it, so turning pages never resizes.
    var expandedHeight: CGFloat {
        let tallest = expandedPages.map { page in page.map(height(of:)) }.map(Self.stackHeight).max()
        guard let tallest else { return Self.expandedBaseHeight + Self.emptyExpandedHeight }
        let dots: CGFloat = spreadCount > 1 ? Self.pageDotsHeight : 0
        return Self.expandedBaseHeight + tallest + dots
    }

    private static func stackHeight(_ sections: [CGFloat]) -> CGFloat {
        sections.reduce(0, +) + CGFloat(max(0, sections.count - 1)) * sectionGap
    }

    /// The whole width of the screen, so the wings grow as long as their content needs,
    /// and enough height for the tallest expanded panel there could be.
    var canvasSize: CGSize {
        let pluginSection = PluginSection.headerHeight + CGFloat(PluginSection.maxRows) * PluginSection.detailRowHeight + PluginSection.filesHeight + PluginSection.buttonsHeight + Self.sectionGap
        let tallest = Self.mediaCardHeight + Self.eventRowHeight + CGFloat(Self.canvasPluginSections) * pluginSection
        return CGSize(width: screenWidth, height: Self.expandedBaseHeight + tallest + Self.canvasSlack)
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
                IslandFrame(size: CGSize(width: notchWidth + Self.cardWings, height: Self.hudHeight), centerOffset: 0)
            }
        case .expanded:
            IslandFrame(size: CGSize(width: expandedWidth, height: expandedHeight), centerOffset: 0)
        }
    }

    /// A wing a HUD doesn't claim keeps its closed width. A notification puts the app's
    /// icon in the left wing, which widens to fit it if it had nothing.
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

    /// The notch with a wing either side, at notch height unless a row opens underneath.
    private func wingsFrame(leading: CGFloat, trailing: CGFloat, below extraHeight: CGFloat = 0) -> IslandFrame {
        IslandFrame(
            size: CGSize(width: notchWidth + Self.sideOverlap * 2 + leading + trailing, height: notchHeight + overlap + extraHeight),
            centerOffset: (trailing - leading) / 2
        )
    }

    /// The closed wing item under a canvas x, if any: the wings are laid out from the
    /// notch outward exactly as `leftWing`/`rightWing` measure them.
    func item(at x: CGFloat) -> WingItem? {
        let centre = canvasSize.width / 2
        let notchLeft = centre - notchWidth / 2 - Self.sideOverlap
        let notchRight = centre + notchWidth / 2 + Self.sideOverlap
        let side = x < centre ? wings.left : wings.right
        let visible = visibleItems(side)
        guard !visible.isEmpty else { return nil }
        var cursor = x < centre ? notchLeft - leftWing + Self.wingPadding : notchRight + Self.wingPadding
        for (index, item) in visible.enumerated() {
            if index > 0 { cursor += wings.gap(between: visible[index - 1], and: item).width }
            let end = cursor + Self.contentWidth(widths(of: item))
            if x >= cursor - Self.partGap && x <= end + Self.partGap { return item }
            cursor = end
        }
        return nil
    }

    /// The expanded page that shows what a wing item stands for.
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
