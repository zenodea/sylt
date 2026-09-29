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
            shape.fill(.black)
                .shadow(
                    color: .black.opacity(state.layout.isFullscreen ? 0 : 0.45),
                    radius: 6 + (size.height - state.notchHeight) * 0.05, y: 3
                )
            ZStack(alignment: .top) {
                shape.fill(.black)
                content
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .offset(x: frame.centerOffset)
                    .id(state.mode.showsClosedContent ? IslandMode.closed : state.mode)
                    .transition(.blurReplace.combined(with: .opacity))
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .clipShape(shape)
            .contentShape(shape)
            .modifier(CursorPull(cursor: state.cursor, enabled: state.mode == .peek))
            .scaleEffect(isPressed ? 0.97 : 1, anchor: .top)
            .onContinuousHover { phase in
                guard case .active(let location) = phase else { return state.hoverChanged(false) }
                let hitFrame = state.layout.hitFrame(for: state.mode)
                let inside = hitFrame.contains(location)
                state.hoverChanged(inside)
                if inside {
                    let origin = CGPoint(x: location.x - (canvas.width - size.width) / 2 - frame.centerOffset, y: location.y)
                    state.cursorMoved(to: origin, in: size)
                }
            }
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
                withAnimation(IslandAnimation.cursor) { isPressed = true }
                state.pressed()
            }
            .onEnded { _ in
                guard isPressed else { return }
                withAnimation(IslandAnimation.cursor) { isPressed = false }
                state.released()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .closed, .peek: ClosedView(layout: state.layout)
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
