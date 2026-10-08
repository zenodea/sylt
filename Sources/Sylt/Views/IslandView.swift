import SwiftUI
import UniformTypeIdentifiers

struct IslandView: View {
    @ObservedObject var state: IslandState
    let openSettings: () -> Void
    @State private var isPressed = false
    @State private var dropTargeted = false

    var body: some View {
        let frame = state.islandFrame
        let size = frame.size
        let canvas = state.canvasSize
        let shape = IslandShape(frame: frame, notchHeight: state.notchHeight)
        let notch = IslandFrame(size: CGSize(width: state.notchWidth, height: state.notchHeight + IslandLayout.notchOverlap), centerOffset: 0)

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
                    if state.absorbsCursor, state.preferences.showsRimGlow, state.preferences.holdsPointer {
                        RimGlow(shape: shape, point: state.exitPoint, strength: state.pullStrength).fadeTop()
                    }
                    if let burst = state.burst {
                        switch state.preferences.releaseEffect {
                        case .ring: ReleaseBurst(point: burst.point).id(burst.id).fadeTop()
                        case .glass: GlassFlash(shape: shape, point: burst.point, direction: burst.direction).id(burst.id).fadeTop()
                        default: EmptyView()
                        }
                    }
                }
                .clipShape(shape)
            }
            .background {
                Liquid(shape: shape, event: state.liquid, strength: state.preferences.rippleStrength, width: state.preferences.rippleWidth)
                    .frame(width: canvas.width, height: canvas.height)
                if let sparks = state.sparks, state.preferences.releaseEffect == .sparks {
                    Sparks(event: sparks).frame(width: canvas.width, height: canvas.height).id(sparks.id)
                }
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .animation(IslandAnimation.value, value: state.layout)
            .contentShape(shape)
            .modifier(CursorPull(cursor: state.cursor, enabled: state.isHovering && state.mode != .expanded))
            .scaleEffect(y: isPressed ? 0.95 : 1, anchor: .top)
            .modifier(SwipeStretch(pull: state.cursorPull))
            .gesture(pressGesture, including: state.mode == .expanded ? .subviews : .all)
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                Task { state.dropped(await Self.urls(from: providers)) }
                return true
            }
            .onChange(of: dropTargeted) { _, targeted in if targeted { state.dragEntered() } }
            .contextMenu {
                Button("Settings…", action: openSettings)
                Divider()
                Button("Quit Sylt") { NSApp.terminate(nil) }
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .coordinateSpace(name: ListFramesKey.space)
        .onPreferenceChange(ListFramesKey.self) { frames in state.listFrames = state.mode == .expanded ? frames : [] }
        .environmentObject(state.battery)
        .environmentObject(state.volume)
        .environmentObject(state.brightness)
        .environmentObject(state.nowPlaying)
        .environmentObject(state.preferences)
        .environmentObject(state.calendar)
        .environmentObject(state.privacy)
        .environmentObject(state.focus)
        .environmentObject(state.bluetooth)
        .environmentObject(state.plugins)
    }

    private static func urls(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) { urls.append(url) }
            else if let url = item as? URL { urls.append(url) }
        }
        return urls
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

    /// Closed and wing-based HUDs share one branch so the wings keep their identity between them.
    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .locked, .hud(.unlocked): LockedView(layout: state.layout, unlocked: state.mode != .locked)
        case .closed, .hud: WingsView(mode: state.mode, layout: state.layout)
        case .expanded: ExpandedView(notchHeight: state.notchHeight, layout: state.layout, pageDirection: state.pageDirection)
        }
    }
}
