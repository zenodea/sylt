import SwiftUI

struct IslandView: View {
    @ObservedObject var state: IslandState

    var body: some View {
        let size = state.islandSize
        let shape = IslandShape(notchHeight: state.notchHeight)

        ZStack(alignment: .top) {
            shape.fill(.black)
            content
                .id(state.mode)
                .transition(.blurReplace.combined(with: .opacity))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .onHover { state.hoverChanged($0) }
        .animation(IslandAnimation.transition(to: state.mode), value: state.mode)
        .frame(width: state.canvasSize.width, height: state.canvasSize.height, alignment: .top)
        .environmentObject(state.battery)
        .environmentObject(state.volume)
        .environmentObject(state.herdr)
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .closed: ClosedView(state: state)
        case .hud(let kind): HUDView(kind: kind, notchHeight: state.notchHeight)
        case .expanded: ExpandedView(state: state)
        }
    }
}
