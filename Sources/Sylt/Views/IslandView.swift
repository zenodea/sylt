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
        let layout = state.layout
        let anchor = layout.anchor
        let rect = layout.rect(of: frame)
        // Without a notch to match, the closed island is a capsule, or rounds generously into its corner.
        let closedRadius = layout.hasNotch ? preferences.cornerRadius : max(preferences.cornerRadius, Self.notchlessRadius)
        let shape = IslandShape(frame: frame, origin: rect.origin, flush: anchor.flush, radius: isOpen ? preferences.openCornerRadius : closedRadius)
        let attachment = anchor.attachment(of: rect)
        let attached = UnitPoint(x: attachment.x / max(canvas.width, 1), y: attachment.y / max(canvas.height, 1))
        let swipeAnchor = layout.hasNotch
            ? UnitPoint(x: state.cursorPull.dx > 0 ? 0 : 1, y: 0)
            : UnitPoint(x: (state.cursorPull.dx > 0 ? rect.minX : rect.maxX) / max(canvas.width, 1), y: attached.y)
        let frosted = preferences.frostedEdges
        let liquid = preferences.liquidGlass && GlassCard.isAvailable
        let surfaceRipples = frosted && liquid
        let notch = layout.hasNotch ? CGSize(width: layout.notchWidth, height: state.notchHeight) : .zero
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
            if state.isMoving {
                PlacementTargets(layout: layout).frame(width: canvas.width, height: canvas.height).transition(.opacity)
            }
            ZStack(alignment: .top) {
                // Hidden under Liquid Glass: the shadow and the ring the hollowing leaves at the
                // outline read as a second dark line beyond the lit edge.
                shape.fill(.black)
                    .shadow(
                        color: .black.opacity(state.layout.isFullscreen ? 0 : state.isMoving ? 0.6 : 0.4),
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
                        .offset(x: rect.midX - canvas.width / 2, y: rect.minY)
                        .id(state.mode.contentIdentity)
                        .transition(IslandAnimation.content)
                    if state.absorbsCursor, preferences.showsRimGlow, preferences.holdsPointer {
                        RimGlow(shape: shape, point: state.exitPoint, strength: state.pullStrength).fadeEdges(anchor.flush, in: canvas)
                    } else if state.approachStrength > 0 {
                        RimGlow(shape: shape, point: state.approachPoint, strength: state.approachStrength * 0.7).fadeEdges(anchor.flush, in: canvas)
                    }
                    if let burst = state.burst {
                        switch preferences.releaseEffect {
                        case .ring: ReleaseBurst(point: burst.point).id(burst.id).fadeEdges(anchor.flush, in: canvas)
                        case .glass: GlassFlash(shape: shape, point: burst.point, direction: burst.direction).id(burst.id).fadeEdges(anchor.flush, in: canvas)
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
            .modifier(CursorPull(cursor: state.cursor, enabled: state.isHovering && !isOpen, anchor: attached))
            // A press swells rather than squashes: anything smaller would uncover the notch.
            .scaleEffect(x: isPressed ? 1.02 : 1, y: isPressed ? 1.05 : 1, anchor: attached)
            // Lifted while it is being moved.
            .scaleEffect(state.isMoving ? 1.04 : 1, anchor: attached)
            .modifier(SwipeStretch(pull: state.cursorPull, anchor: swipeAnchor))
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

    private static let notchlessRadius: CGFloat = 16

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
                guard !isPressed, state.mode != .expanded, !state.isMoving else { return }
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
        case .expanded: ExpandedView(header: state.layout.expandedHeader, layout: state.layout, pageDirection: state.pageDirection)
        }
    }
}
