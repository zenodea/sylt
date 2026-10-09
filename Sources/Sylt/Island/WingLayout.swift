import Foundation

/// One thing a closed wing can show.
enum WingItem: Hashable, Codable {
    case calendar, privacy, focus, headphones, music
    case wifi, bluetooth, volume, battery
    case plugin(String)

    static let builtIn: [WingItem] = [.calendar, .privacy, .focus, .headphones, .music] + menuBar
    /// What the menu bar shows. Hidden until placed, so the island can stand in for it.
    static let menuBar: [WingItem] = [.wifi, .bluetooth, .volume, .battery]

    var id: String {
        switch self {
        case .calendar: "calendar"
        case .privacy: "privacy"
        case .focus: "focus"
        case .headphones: "headphones"
        case .music: "music"
        case .wifi: "wifi"
        case .bluetooth: "bluetooth"
        case .volume: "volume"
        case .battery: "battery"
        case .plugin(let id): "plugin:\(id)"
        }
    }

    init?(id: String) {
        if let item = Self.builtIn.first(where: { $0.id == id }) { self = item }
        else if id.hasPrefix("plugin:") { self = .plugin(String(id.dropFirst(7))) }
        else { return nil }
    }

    var title: String {
        switch self {
        case .calendar: "Next event"
        case .privacy: "Mic and camera"
        case .focus: "Focus"
        case .headphones: "Headphones"
        case .music: "Now playing"
        case .wifi: "Wi-Fi"
        case .bluetooth: "Bluetooth"
        case .volume: "Volume"
        case .battery: "Battery"
        case .plugin(let id): id
        }
    }

    var symbol: String {
        switch self {
        case .calendar: "calendar"
        case .privacy: "circle.fill"
        case .focus: "moon.fill"
        case .headphones: "headphones"
        case .music: "music.note"
        case .wifi: "wifi"
        case .bluetooth: "dot.radiowaves.right"
        case .volume: "speaker.wave.2.fill"
        case .battery: "battery.75percent"
        case .plugin: "puzzlepiece.extension.fill"
        }
    }

    /// The monitor a placed menu bar item keeps running, whatever its plugin toggle says.
    var monitorPlugin: Plugin? {
        switch self {
        case .wifi: .network
        case .bluetooth: .bluetooth
        case .volume: .volume
        case .battery: .battery
        default: nil
        }
    }

    /// Where it goes unless the user says otherwise.
    var naturalSide: WingSide {
        self == .calendar ? .left : .right
    }
}

enum WingSide: String, Codable, CaseIterable {
    case left, right
}

/// A plugin as the layout sees it: its id and the side it would take on its own.
struct WingPlugin: Equatable {
    let id: String
    let side: WingSide
}

/// The space after an item, before whatever shows next to it, and whether a thin line
/// sits in it. It belongs to the item, so it holds when a neighbour is idle or moved.
struct WingGap: Codable, Equatable {
    static let defaultSpacing: Double = 8
    static let separatorWidth: CGFloat = 1

    var spacing: Double = defaultSpacing
    var separator = false

    /// The room the gap takes in the wing.
    var width: CGFloat { CGFloat(spacing) + (separator ? Self.separatorWidth : 0) }
}

/// What the closed wings show, in order, after the user's choices are applied.
struct ResolvedWings: Equatable {
    var left: [WingItem] = [.calendar]
    var right: [WingItem] = [.privacy, .focus, .headphones, .music]
    var gaps: [String: WingGap] = [:]

    func gap(between first: WingItem, and second: WingItem) -> WingGap {
        gaps[WingLayout.gapKey(first, second)] ?? WingGap()
    }

    /// The gap after an item, whatever follows it.
    func gap(after item: WingItem) -> WingGap {
        gaps[item.id] ?? WingGap()
    }
}

/// The user's wing layout: which items sit left, right or nowhere, in what order,
/// and how much room sits between neighbours. Anything not mentioned keeps its
/// natural place, so new plugins need no migration.
struct WingLayout: Codable, Equatable {
    var left: [String] = []
    var right: [String] = []
    var hidden: [String] = []
    var gaps: [String: WingGap] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = try container.decodeIfPresent([String].self, forKey: .left) ?? []
        right = try container.decodeIfPresent([String].self, forKey: .right) ?? []
        hidden = try container.decodeIfPresent([String].self, forKey: .hidden) ?? []
        // Gaps used to be keyed by the pair of neighbours; now by the item before the gap.
        let stored = try container.decodeIfPresent([String: WingGap].self, forKey: .gaps) ?? [:]
        gaps = Dictionary(stored.map { (String($0.key.split(separator: ">").first ?? ""), $0.value) }) { first, _ in first }
    }

    var isCustomised: Bool { !left.isEmpty || !right.isEmpty || !hidden.isEmpty || !gaps.isEmpty }

    /// A gap is keyed by the item in front of it; the item behind doesn't matter.
    static func gapKey(_ first: WingItem, _ second: WingItem) -> String { first.id }

    func gap(between first: WingItem, and second: WingItem) -> WingGap {
        gaps[Self.gapKey(first, second)] ?? WingGap()
    }

    mutating func setGap(_ gap: WingGap, between first: WingItem, and second: WingItem) {
        gaps[Self.gapKey(first, second)] = gap == WingGap() ? nil : gap
    }

    func resolve(plugins: [WingPlugin]) -> ResolvedWings {
        let natural = Self.natural(plugins: plugins)
        let mentioned = Set(left + right + hidden)
        func items(_ ids: [String], then rest: [WingItem]) -> [WingItem] {
            ids.compactMap { id in
                guard let item = WingItem(id: id) else { return nil }
                if case .plugin(let pluginID) = item, !plugins.contains(where: { $0.id == pluginID }) { return nil }
                return item
            } + rest.filter { !mentioned.contains($0.id) }
        }
        return ResolvedWings(left: items(left, then: natural.left), right: items(right, then: natural.right), gaps: gaps)
    }

    /// The core monitors the placed menu bar items need.
    var monitorsNeeded: Set<Plugin> {
        Set((left + right).compactMap(WingItem.init(id:)).compactMap(\.monitorPlugin))
    }

    /// Every item the layout places on its own, in natural order, for the designer.
    static func natural(plugins: [WingPlugin]) -> ResolvedWings {
        let leftPlugins = plugins.filter { $0.side == .left }.map { WingItem.plugin($0.id) }
        let rightPlugins = plugins.filter { $0.side == .right }.map { WingItem.plugin($0.id) }
        return ResolvedWings(
            left: [.calendar] + leftPlugins,
            right: [.privacy, .focus, .headphones] + rightPlugins + [.music]
        )
    }

    /// Where an item is after resolution, for the designer's three columns.
    func column(of item: WingItem, plugins: [WingPlugin]) -> WingColumn {
        if hidden.contains(item.id) { return .hidden }
        let resolved = resolve(plugins: plugins)
        if resolved.left.contains(item) { return .left }
        if resolved.right.contains(item) { return .right }
        return .hidden
    }

    /// Put an item in a column, before `target` when given, otherwise at the end. The
    /// layout is first made explicit so the move doesn't reshuffle the natural order.
    mutating func move(_ item: WingItem, to column: WingColumn, before target: WingItem? = nil, plugins: [WingPlugin]) {
        let resolved = resolve(plugins: plugins)
        left = resolved.left.map(\.id)
        right = resolved.right.map(\.id)
        left.removeAll { $0 == item.id }
        right.removeAll { $0 == item.id }
        hidden.removeAll { $0 == item.id }
        func insert(into list: inout [String]) {
            if let target, target != item, let index = list.firstIndex(of: target.id) { list.insert(item.id, at: index) }
            else { list.append(item.id) }
        }
        switch column {
        case .left: insert(into: &left)
        case .right: insert(into: &right)
        case .hidden: hidden.append(item.id)
        }
    }
}

enum WingColumn: String, CaseIterable, Identifiable {
    case left, right, hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left wing"
        case .right: "Right wing"
        case .hidden: "Hidden"
        }
    }
}
