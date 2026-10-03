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
                    if state.absorbsCursor {
                        RimGlow(shape: shape, point: state.exitPoint, strength: state.pullStrength)
                    }
                    if let burst = state.burst {
                        ReleaseBurst(point: burst.point).id(burst.id)
                    }
                }
                .clipShape(shape)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .contentShape(shape)
            .modifier(CursorPull(cursor: state.cursor, enabled: state.isHovering && state.mode != .expanded))
            .scaleEffect(y: isPressed ? 0.95 : 1, anchor: .top)
            .modifier(SwipeStretch(pull: CGVector(
                dx: min(max(state.swipePull.dx + state.cursorPull.dx, -1), 1),
                dy: min(max(state.swipePull.dy + state.cursorPull.dy, -1), 1)
            )))
            .gesture(pressGesture, including: state.mode == .expanded ? .subviews : .all)
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                Task { state.dropped(await Self.urls(from: providers)) }
                return true
            }
            .onChange(of: dropTargeted) { _, targeted in if targeted { state.dragEntered() } }
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

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .locked, .hud(.unlocked): LockedView(layout: state.layout, unlocked: state.mode != .locked)
        case .closed, .hud:
            // One branch for closed and wing-based HUDs, so the wings keep their identity between them.
            if case .hud(.notification(let notification)) = state.mode {
                NotificationCard(notification: notification, layout: state.layout)
            } else {
                WingsView(mode: state.mode, layout: state.layout)
            }
        case .expanded: ExpandedView(notchHeight: state.notchHeight, layout: state.layout)
        }
    }
}

/// The flash where the pointer just left: a ring that expands and fades at the rim.
private struct ReleaseBurst: View {
    let point: CGPoint
    @State private var fired = false

    var body: some View {
        Circle()
            .stroke(.white.opacity(fired ? 0 : 0.7), lineWidth: fired ? 1 : 3)
            .background(Circle().fill(.white.opacity(fired ? 0 : 0.25)))
            .frame(width: 24, height: 24)
            .scaleEffect(fired ? 3.2 : 0.4)
            .position(point)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 0.45)) { fired = true } }
    }
}

/// The island's edge lighting up where the held pointer would come out, brighter the harder it is pushed.
private struct RimGlow: View {
    let shape: IslandShape
    let point: CGPoint
    let strength: CGFloat

    var body: some View {
        shape
            .stroke(.white, lineWidth: 2.5)
            .blur(radius: 1.5)
            .mask(
                Circle()
                    .fill(RadialGradient(colors: [.white, .white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 46))
                    .frame(width: 92, height: 92)
                    .position(point)
            )
            .opacity(0.15 + strength * 0.85)
            .opacity(strength > 0.03 ? 1 : 0)
            .animation(IslandAnimation.cursor, value: point)
            .animation(IslandAnimation.cursor, value: strength)
            .allowsHitTesting(false)
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
