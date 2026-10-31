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
        let preferences = state.preferences
        let isOpen = state.mode == .expanded
        let shape = IslandShape(frame: frame, radius: isOpen ? preferences.openCornerRadius : preferences.cornerRadius)
        let frosted = preferences.frostedEdges
        let liquid = preferences.liquidGlass && GlassCard.isAvailable
        let surfaceRipples = frosted && liquid
        let notch = CGSize(width: state.layout.notchWidth, height: state.notchHeight)
        let closedSize = state.layout.frame(for: .closed, hovering: state.isHovering).size
        let openSize = state.layout.frame(for: .expanded, hovering: false).size
        let glass = GlassStates(
            closed: .init(reach: CGSize(width: preferences.glassReachWidth, height: preferences.glassReachHeight), opacity: preferences.glassOpacity, blur: preferences.glassBlur),
            open: .init(reach: CGSize(width: preferences.openGlassReachWidth, height: preferences.openGlassReachHeight), opacity: preferences.openGlassOpacity, blur: preferences.openGlassBlur),
            heights: closedSize.height...max(openSize.height, closedSize.height),
            widths: closedSize.width...max(openSize.width, closedSize.width),
            followsSize: isOpen || state.mode == .closed
        )

        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                // Hidden under Liquid Glass: the shadow and the ring the hollowing leaves at the
                // outline read as a second dark line beyond the lit edge.
                shape.fill(.black)
                    .shadow(
                        color: .black.opacity(state.layout.isFullscreen ? 0 : 0.4),
                        radius: 5 + (size.height - state.notchHeight) * 0.06,
                        y: 2 + (size.height - state.notchHeight) * 0.03
                    )
                    .hollowed(by: shape, if: frosted)
                    .opacity(surfaceRipples ? 0 : 1)
                IslandSurface(
                    shape: shape,
                    notch: notch,
                    glass: glass,
                    tint: preferences.glassTint,
                    frosted: frosted,
                    liquid: liquid,
                    ripple: (state.liquid, preferences.rippleStrength, preferences.rippleWidth)
                )
                ZStack(alignment: .top) {
                    Color.clear
                    content
                        .frame(width: size.width, height: size.height, alignment: .top)
                        .offset(x: frame.centerOffset)
                        .id(state.mode.contentIdentity)
                        .transition(IslandAnimation.content)
                    if state.absorbsCursor, preferences.showsRimGlow, preferences.holdsPointer {
                        RimGlow(shape: shape, point: state.exitPoint, strength: state.pullStrength).fadeTop()
                    } else if state.approachStrength > 0 {
                        RimGlow(shape: shape, point: state.approachPoint, strength: state.approachStrength * 0.7).fadeTop()
                    }
                    if let burst = state.burst {
                        switch preferences.releaseEffect {
                        case .ring: ReleaseBurst(point: burst.point).id(burst.id).fadeTop()
                        case .glass: GlassFlash(shape: shape, point: burst.point, direction: burst.direction).id(burst.id).fadeTop()
                        default: EmptyView()
                        }
                    }
                }
                .clipShape(shape)
            }
            .background {
                ZStack {
                    Liquid(shape: shape, event: surfaceRipples ? nil : state.liquid, strength: preferences.rippleStrength, width: preferences.rippleWidth)
                        .frame(width: canvas.width, height: canvas.height)
                    if let sparks = state.sparks, preferences.releaseEffect == .sparks {
                        Sparks(event: sparks).frame(width: canvas.width, height: canvas.height).id(sparks.id)
                    }
                }
                .hollowed(by: shape, if: frosted)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .animation(IslandAnimation.value, value: state.layout)
            .contentShape(shape)
            .modifier(CursorPull(cursor: state.cursor, enabled: state.isHovering && !isOpen))
            // A press swells rather than squashes: anything smaller would uncover the notch.
            .scaleEffect(x: isPressed ? 1.02 : 1, y: isPressed ? 1.05 : 1, anchor: .top)
            .modifier(SwipeStretch(pull: state.cursorPull))
            .gesture(pressGesture, including: isOpen ? .subviews : .all)
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
        .environmentObject(state.network)
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

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .locked, .hud(.unlocked): LockedView(layout: state.layout, unlocked: state.mode != .locked)
        case .closed, .hud: WingsView(mode: state.mode, layout: state.layout)
        case .expanded: ExpandedView(notchHeight: state.notchHeight, layout: state.layout, pageDirection: state.pageDirection)
        }
    }
}
