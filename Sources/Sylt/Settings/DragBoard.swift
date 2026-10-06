import SwiftUI

/// Reordering by plain dragging: tiles report their frames, a drag lifts one tile and
/// follows the pointer, the tile it would land before slides down to make room, and
/// letting go hands the move to the owner. No system drag and drop, so nothing is rebuilt
/// mid-gesture.
@MainActor
final class DragBoard: ObservableObject {
    struct Drop: Equatable {
        let column: String
        let index: Int
    }

    @Published private(set) var dragging: String?
    @Published private(set) var translation: CGSize = .zero
    @Published private(set) var drop: Drop?
    /// Where the lifted tile was when picked up; the floating copy starts there and
    /// moves only by the pointer's travel, whatever the lists below do meanwhile.
    private(set) var liftFrame: CGRect = .zero
    private(set) var frames: [String: CGRect] = [:]
    /// Tiles per column, in order, as currently rendered.
    var columns: [String: [String]] = [:]

    func report(_ frames: [String: CGRect]) {
        self.frames.merge(frames) { $1 }
    }

    func update(_ item: String, location: CGPoint, translation: CGSize) {
        if dragging != item {
            liftFrame = frame(of: item)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dragging = item }
        }
        self.translation = translation
        let target = columns.keys.first { frames["column:\($0)"]?.insetBy(dx: -10, dy: -10).contains(location) == true }
        guard let target else { return drop = nil }
        let others = (columns[target] ?? []).filter { $0 != item }
        let index = others.filter { (frames["tile:\($0)"]?.midY ?? .infinity) < location.y }.count
        drop = Drop(column: target, index: index)
    }

    /// Where the tile would go, then the gesture is over.
    func end() -> (item: String, column: String, before: String?)? {
        defer {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dragging = nil; translation = .zero; drop = nil }
        }
        guard let dragging, let drop else { return nil }
        let others = (columns[drop.column] ?? []).filter { $0 != dragging }
        return (dragging, drop.column, drop.index < others.count ? others[drop.index] : nil)
    }

    func frame(of item: String) -> CGRect { frames["tile:\(item)"] ?? .zero }

    /// The slot in `column` that opens for the dragged tile, if any.
    func gap(in column: String) -> Int? {
        guard let drop, drop.column == column else { return nil }
        return drop.index
    }
}

struct BoardFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

extension View {
    /// Reports this view's frame to the board under `key`, in the board's coordinate space.
    func boardFrame(_ key: String, space: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: BoardFramesKey.self, value: [key: proxy.frame(in: .named(space))])
        })
    }
}
