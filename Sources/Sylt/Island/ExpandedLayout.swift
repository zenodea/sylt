import Foundation

enum ExpandedSection: Hashable, Codable {
    case media, event
    case plugin(String)

    var id: String {
        switch self {
        case .media: "media"
        case .event: "event"
        case .plugin(let id): StoredID.plugin(id)
        }
    }

    init?(id: String) {
        switch id {
        case "media": self = .media
        case "event": self = .event
        default:
            guard let plugin = StoredID.pluginID(in: id) else { return nil }
            self = .plugin(plugin)
        }
    }

    var title: String {
        switch self {
        case .media: "Now playing"
        case .event: "Next event"
        case .plugin(let id): id
        }
    }

    var symbol: String {
        switch self {
        case .media: "music.note"
        case .event: "calendar"
        case .plugin: "puzzlepiece.extension.fill"
        }
    }
}

struct ExpandedLayout: Codable, Equatable {
    static let perPage = 2

    var pages: [[String]] = []

    var isCustomised: Bool { !pages.isEmpty }

    func resolve(available: [ExpandedSection]) -> [[ExpandedSection]] {
        var result = pages.map { page in page.compactMap(ExpandedSection.init(id:)).filter(available.contains) }
        let placed = Set(result.flatMap { $0 })
        let rest = available.filter { !placed.contains($0) }
        for start in stride(from: 0, to: rest.count, by: Self.perPage) {
            result.append(Array(rest[start ..< min(start + Self.perPage, rest.count)]))
        }
        return result.filter { !$0.isEmpty }
    }

    mutating func movePage(_ index: Int, by delta: Int, all: [ExpandedSection]) {
        var result = resolve(available: all)
        let target = index + delta
        guard result.indices.contains(index), result.indices.contains(target) else { return }
        result.swapAt(index, target)
        pages = result.map { $0.map(\.id) }
    }

    mutating func move(_ section: ExpandedSection, toPage index: Int, before target: ExpandedSection? = nil, all: [ExpandedSection]) {
        var result = resolve(available: all)
        for page in result.indices { result[page].removeAll { $0 == section } }
        if index < result.count {
            if let target, target != section, let position = result[index].firstIndex(of: target) {
                result[index].insert(section, at: position)
            } else {
                result[index].append(section)
            }
        } else {
            result.append([section])
        }
        pages = result.filter { !$0.isEmpty }.map { $0.map(\.id) }
    }
}
