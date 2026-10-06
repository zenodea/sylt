import Foundation

/// One block of the expanded view.
enum ExpandedSection: Hashable, Codable {
    case media, event
    case plugin(String)

    var id: String {
        switch self {
        case .media: "media"
        case .event: "event"
        case .plugin(let id): "plugin:\(id)"
        }
    }

    init?(id: String) {
        switch id {
        case "media": self = .media
        case "event": self = .event
        default:
            guard id.hasPrefix("plugin:") else { return nil }
            self = .plugin(String(id.dropFirst(7)))
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

/// Which sections share a page of the expanded view. Sections not mentioned are dealt
/// onto pages after the explicit ones, two to a page, so nothing needs setting up.
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

    /// Put a section on a page, before `target` when given. A page index past the end
    /// starts a new page. Every page is first made explicit so nothing else moves.
    /// Move a whole page earlier or later; `delta` is -1 or +1.
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
