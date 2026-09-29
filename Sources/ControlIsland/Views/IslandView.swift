import SwiftUI

struct IslandView: View {
    @ObservedObject var state: IslandState
    let openSettings: () -> Void
    @State private var isPressed = false

    var body: some View {
        let frame = state.islandFrame
        let size = frame.size
        let canvas = state.canvasSize
        let shape = IslandShape(frame: frame, notchHeight: state.notchHeight)
        let notch = IslandFrame(size: CGSize(width: state.notchWidth, height: state.notchHeight), centerOffset: 0)

        ZStack(alignment: .top) {
            IslandShape(frame: notch, notchHeight: state.notchHeight)
                .fill(.black)
            ZStack(alignment: .top) {
                shape.fill(.black)
                    .shadow(
                        color: .black.opacity(state.layout.isFullscreen ? 0 : 0.4),
                        radius: 5 + (size.height - state.notchHeight) * 0.06,
                        y: 2 + (size.height - state.notchHeight) * 0.03
                    )
                ZStack(alignment: .top) {
                    shape.fill(.black)
                    content
                        .frame(width: size.width, height: size.height, alignment: .top)
                        .offset(x: frame.centerOffset)
                        .id(state.mode.contentIdentity)
                        .transition(IslandAnimation.content)
                }
                .clipShape(shape)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .contentShape(shape)
            .modifier(CursorPull(cursor: state.cursor, enabled: state.isHovering && state.mode != .expanded))
            .scaleEffect(y: isPressed ? 0.95 : 1, anchor: .top)
            .modifier(SwipeStretch(pull: state.swipePull))
            .gesture(pressGesture, including: state.mode == .expanded ? .subviews : .all)
            .contextMenu {
                Button("Settings…", action: openSettings)
                Divider()
                Button("Quit Control Island") { NSApp.terminate(nil) }
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .environmentObject(state.battery)
        .environmentObject(state.volume)
        .environmentObject(state.brightness)
        .environmentObject(state.herdr)
        .environmentObject(state.nowPlaying)
        .environmentObject(state.preferences)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed, state.mode != .expanded else { return }
                withAnimation(IslandAnimation.press) { isPressed = true }
                state.pressed()
            }
            .onEnded { _ in
                guard isPressed else { return }
                withAnimation(IslandAnimation.press) { isPressed = false }
                state.released()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .closed: ClosedView(layout: state.layout)
        case .locked, .hud(.unlocked): LockedView(layout: state.layout, unlocked: state.mode != .locked)
        case .hud(let kind): HUDView(kind: kind, layout: state.layout)
        case .expanded: ExpandedView(notchHeight: state.notchHeight)
        }
    }
}

private struct CursorPull: ViewModifier {
    let cursor: CGPoint
    let enabled: Bool

    func body(content: Content) -> some View {
        let pull = enabled ? cursor : .zero
        content
            .scaleEffect(x: 1 + abs(pull.x) * 0.015, y: 1 + pull.y * 0.06, anchor: .top)
            .animation(IslandAnimation.cursor, value: pull)
    }
}

/// Leans the island toward a swipe by growing the far edge, so the edge over
/// the notch and the top edge never move.
private struct SwipeStretch: ViewModifier {
    let pull: CGVector

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 1 + abs(pull.dx) * 0.04,
                y: 1 + max(0, pull.dy) * 0.08,
                anchor: UnitPoint(x: pull.dx > 0 ? 0 : 1, y: 0)
            )
    }
}
