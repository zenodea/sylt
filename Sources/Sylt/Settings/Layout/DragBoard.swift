import SwiftUI

/// Reordering by plain dragging, with no system drag and drop so nothing is rebuilt
/// mid-gesture: tiles report their frames, a drag lifts one and follows the pointer, the
/// tile it would land before slides down to make room, and letting go hands the move to the owner.
@MainActor
final class DragBoard: ObservableObject {
    struct Drop: Equatable {
        let column: String
        let index: Int
    }

    struct Result {
        let item: String
        let column: String
        let before: String?
    }

    static let tileHeight: CGFloat = 32

    @Published private(set) var dragging: String?
    @Published private(set) var translation: CGSize = .zero
    @Published private(set) var drop: Drop?
    /// Let go: the lifted tile is springing into its slot before the lists take over.
    @Published private(set) var settling = false
    private static let settleTime: TimeInterval = 0.26
    /// Where the lifted tile was picked up; the floating copy moves from there by the pointer's travel alone.
    private(set) var liftFrame: CGRect = .zero
    private var frames: [String: CGRect] = [:]

    func report(_ frames: [String: CGRect]) {
        self.frames.merge(frames) { $1 }
    }

    /// `columns` holds each column's tiles in the order they are shown.
    func update(_ item: String, location: CGPoint, translation: CGSize, columns: [String: [String]]) {
        if dragging != item {
            liftFrame = frames["tile:\(item)"] ?? .zero
            withTransaction(.unanimated) { dragging = item }
        }
        self.translation = translation
        let target = columns.keys.first { frames["column:\($0)"]?.insetBy(dx: -10, dy: -10).contains(location) == true }
        guard let target else { return drop = nil }
        let others = (columns[target] ?? []).filter { $0 != item }
        let index = others.filter { (frames["tile:\($0)"]?.midY ?? .infinity) < location.y }.count
        drop = Drop(column: target, index: index)
    }

    /// Letting go: the floating tile springs into the open slot, and only once it is
    /// there do the lists change under it, so the swap is invisible.
    func end(columns: [String: [String]], then dropped: @escaping (Result) -> Void) {
        guard let dragging, let drop, !settling else { return clear() }
        let others = (columns[drop.column] ?? []).filter { $0 != dragging }
        let result = Result(item: dragging, column: drop.column, before: drop.index < others.count ? others[drop.index] : nil)
        guard let slot = frames["slot:\(drop.column)"], slot.height > 0 else {
            clear()
            return dropped(result)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            settling = true
            translation = CGSize(width: slot.minX - liftFrame.minX, height: slot.minY + 2 - liftFrame.minY)
        }
        Timer.after(Self.settleTime) { [weak self] in
            self?.clear()
            dropped(result)
        }
    }

    private func clear() {
        withTransaction(.unanimated) {
            dragging = nil
            translation = .zero
            drop = nil
            settling = false
        }
    }

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

    /// A tile the board can lift: it folds away while it is the one being dragged, and
    /// letting go hands where it landed to `dropped`.
    func boardTile(_ id: String, on board: DragBoard, space: String, columns: [String: [String]], dropped: @escaping (DragBoard.Result) -> Void) -> some View {
        boardFrame("tile:\(id)", space: space)
            .opacity(board.dragging == id ? 0 : 1)
            .frame(height: board.dragging == id ? 0 : nil)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(space))
                    .onChanged { board.update(id, location: $0.location, translation: $0.translation, columns: columns) }
                    .onEnded { _ in board.end(columns: columns, then: dropped) }
            )
    }

    /// The copy of the dragged tile that follows the pointer.
    func lifted(by board: DragBoard) -> some View {
        frame(width: board.liftFrame.width)
            .scaleEffect(board.settling ? 1 : 1.03)
            .shadow(color: .black.opacity(board.settling ? 0 : 0.25), radius: 8, y: 4)
            .offset(x: board.liftFrame.minX + board.translation.width, y: board.liftFrame.minY + board.translation.height)
            .allowsHitTesting(false)
    }
}
