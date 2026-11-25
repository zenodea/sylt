import CoreGraphics

/// Where the island sits on a screen without a notch: somewhere along one edge, floating a
/// little off it, or flush in a corner, where it takes the corner's shape the way the notch
/// island takes the notch's.
struct IslandPlacement: Codable, Equatable {
    enum Edge: String, Codable, CaseIterable {
        case top, bottom, left, right
    }

    var edge: Edge
    /// Along the edge, from 0 at its start (the left end of the top and bottom edges, the top
    /// end of the sides) to 1 at its end. Exactly 0 or 1 on the top or bottom edge is a corner.
    var position: Double

    static let standard = IslandPlacement(edge: .top, position: 0.5)

    /// The eight targets offered while moving the island and in the Appearance pane.
    static let targets: [IslandPlacement] = [
        IslandPlacement(edge: .top, position: 0), IslandPlacement(edge: .top, position: 0.5), IslandPlacement(edge: .top, position: 1),
        IslandPlacement(edge: .left, position: 0.5), IslandPlacement(edge: .right, position: 0.5),
        IslandPlacement(edge: .bottom, position: 0), IslandPlacement(edge: .bottom, position: 0.5), IslandPlacement(edge: .bottom, position: 1),
    ]

    /// How close to a corner, along both edges, the pointer must come for the island to snap into it.
    static let cornerReach: CGFloat = 96
    /// How close to the middle of an edge the island snaps to it exactly.
    static let middleReach: CGFloat = 24

    init(edge: Edge, position: Double) {
        self.edge = edge
        self.position = min(max(position, 0), 1)
        // A corner belongs to the top or bottom edge, so each corner has one spelling.
        if edge == .left || edge == .right, self.position == 0 || self.position == 1 {
            self.edge = self.position == 0 ? .top : .bottom
            self.position = edge == .left ? 0 : 1
        }
    }

    var isCorner: Bool { (edge == .top || edge == .bottom) && (position == 0 || position == 1) }

    /// The placement nearest a point, in canvas coordinates (y down) on a screen of `size`.
    static func nearest(to point: CGPoint, in size: CGSize) -> IslandPlacement {
        let x = min(max(point.x, 0), size.width), y = min(max(point.y, 0), size.height)
        let nearLeft = x < cornerReach, nearRight = size.width - x < cornerReach
        let nearTop = y < cornerReach, nearBottom = size.height - y < cornerReach
        if (nearLeft || nearRight) && (nearTop || nearBottom) {
            return IslandPlacement(edge: nearTop ? .top : .bottom, position: nearLeft ? 0 : 1)
        }
        let distances: [(Edge, CGFloat)] = [(.top, y), (.bottom, size.height - y), (.left, x), (.right, size.width - x)]
        let edge = distances.min { $0.1 < $1.1 }!.0
        let along = edge == .top || edge == .bottom ? x : y
        let length = edge == .top || edge == .bottom ? size.width : size.height
        guard length > 0 else { return .standard }
        // Short of a corner the island floats, so it never lands on 0 or 1 here.
        let position = abs(along - length / 2) < middleReach ? 0.5 : min(max(Double(along / length), 0.001), 0.999)
        return IslandPlacement(edge: edge, position: position)
    }
}

/// The sides of the island that lie along the screen's edge: they stay square and nothing
/// grows or glows across them.
struct FlushEdges: OptionSet, Hashable {
    let rawValue: Int

    static let top = FlushEdges(rawValue: 1 << 0)
    static let bottom = FlushEdges(rawValue: 1 << 1)
    static let leading = FlushEdges(rawValue: 1 << 2)
    static let trailing = FlushEdges(rawValue: 1 << 3)
}

/// The free space on a screen once the menu bar and the Dock are taken out, as insets.
struct ScreenInsets: Equatable {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0
}

/// How the island hangs on the canvas: the point it is attached to, which part of the island
/// sits on that point, and the room it has to grow into.
struct IslandAnchor: Equatable {
    var point: CGPoint
    /// The fraction of the island's width and height that lies left of and above `point`.
    var align: CGPoint
    var flush: FlushEdges
    /// The island is kept inside these; nil leaves it where the point puts it.
    var bounds: CGRect?
    /// Under a notch the island shifts so its gap stays over the notch while one wing grows;
    /// anywhere else it stays centred on its point.
    var keepsNotchCentred = false

    static func notch(canvasWidth: CGFloat) -> IslandAnchor {
        IslandAnchor(point: CGPoint(x: canvasWidth / 2, y: 0), align: CGPoint(x: 0.5, y: 0), flush: .top, bounds: nil, keepsNotchCentred: true)
    }

    static func placed(_ placement: IslandPlacement, screen: CGSize, insets: ScreenInsets, gap: CGFloat) -> IslandAnchor {
        let (width, height) = (screen.width, screen.height)
        let free = CGRect(x: insets.left, y: insets.top, width: width - insets.left - insets.right, height: height - insets.top - insets.bottom)
        let room = free.insetBy(dx: gap, dy: gap)
        let along = CGFloat(placement.position)
        if placement.isCorner {
            let right = placement.position == 1, bottom = placement.edge == .bottom
            return IslandAnchor(
                point: CGPoint(x: right ? width : 0, y: bottom ? height : 0),
                align: CGPoint(x: right ? 1 : 0, y: bottom ? 1 : 0),
                flush: [bottom ? .bottom : .top, right ? .trailing : .leading],
                bounds: CGRect(origin: .zero, size: screen)
            )
        }
        switch placement.edge {
        case .top:
            return IslandAnchor(point: CGPoint(x: width * along, y: room.minY), align: CGPoint(x: 0.5, y: 0), flush: [], bounds: room)
        case .bottom:
            return IslandAnchor(point: CGPoint(x: width * along, y: room.maxY), align: CGPoint(x: 0.5, y: 1), flush: [], bounds: room)
        case .left:
            return IslandAnchor(point: CGPoint(x: room.minX, y: height * along), align: CGPoint(x: 0, y: 0.5), flush: [], bounds: room)
        case .right:
            return IslandAnchor(point: CGPoint(x: room.maxX, y: height * along), align: CGPoint(x: 1, y: 0.5), flush: [], bounds: room)
        }
    }

    var isFloating: Bool { flush.isEmpty }

    func rect(for frame: IslandFrame) -> CGRect {
        let size = frame.size
        var origin = CGPoint(
            x: point.x - size.width * align.x + (keepsNotchCentred ? frame.centerOffset : 0),
            y: point.y - size.height * align.y
        )
        if let bounds {
            origin.x = Self.fit(origin.x, length: size.width, in: bounds.minX ... bounds.maxX)
            origin.y = Self.fit(origin.y, length: size.height, in: bounds.minY ... bounds.maxY)
        }
        return CGRect(origin: origin, size: size)
    }

    /// The side the island grows away from, as a point on its outline: the attachment.
    func attachment(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * align.x, y: rect.minY + rect.height * align.y)
    }

    private static func fit(_ start: CGFloat, length: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        let room = range.upperBound - range.lowerBound
        guard length < room else { return range.lowerBound + (room - length) / 2 }
        return min(max(start, range.lowerBound), range.upperBound - length)
    }
}
