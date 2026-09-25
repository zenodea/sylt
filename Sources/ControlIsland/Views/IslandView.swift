import SwiftUI

struct IslandView: View {
    @ObservedObject var state: IslandState

    var body: some View {
        let size = state.islandSize
        let shape = IslandShape(notchHeight: state.notchHeight)

        ZStack(alignment: .top) {
            shape.fill(.black)
            content
                .id(state.mode.showsClosedContent ? IslandMode.closed : state.mode)
                .transition(.blurReplace.combined(with: .opacity))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .modifier(CursorPull(cursor: state.cursor, enabled: state.mode == .peek))
        .onHover { state.hoverChanged($0) }
        .onContinuousHover { phase in
            if case .active(let location) = phase { state.cursorMoved(to: location, in: size) }
        }
        .onTapGesture { state.tapped() }
        .animation(IslandAnimation.transition(to: state.mode), value: state.mode)
        .frame(width: state.canvasSize.width, height: state.canvasSize.height, alignment: .top)
        .environmentObject(state.battery)
        .environmentObject(state.volume)
        .environmentObject(state.brightness)
        .environmentObject(state.herdr)
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .closed, .peek: ClosedView(state: state)
        case .hud(let kind): HUDView(kind: kind, notchHeight: state.notchHeight)
        case .expanded: ExpandedView(state: state)
        }
    }
}

private struct CursorPull: ViewModifier {
    let cursor: CGPoint
    let enabled: Bool

    func body(content: Content) -> some View {
        let pull = enabled ? cursor : .zero
        content
            .scaleEffect(x: 1 + abs(pull.x) * 0.02, y: 1 + pull.y * 0.04, anchor: .top)
            .offset(x: pull.x * 5)
            .animation(IslandAnimation.cursor, value: pull)
    }
}
