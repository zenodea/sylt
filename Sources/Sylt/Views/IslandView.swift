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
                        RimGlow(shape: shape, point: state.exitPoint, strength: state.pullStrength)
                            .modifier(FadeTop())
                    }
                    if let burst = state.burst, state.preferences.releaseEffect == .ring {
                        ReleaseBurst(point: burst.point).id(burst.id)
                            .modifier(FadeTop())
                    }
                    if let burst = state.burst, state.preferences.releaseEffect == .glass {
                        GlassFlash(shape: shape, point: burst.point, direction: burst.direction).id(burst.id)
                            .modifier(FadeTop())
                    }
                }
                .clipShape(shape)
            }
            .background {
                Liquid(shape: shape, event: state.liquid, strength: state.preferences.rippleStrength)
                    .frame(width: canvas.width, height: canvas.height)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
            .animation(IslandAnimation.value, value: state.layout)
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
                Button("Quit Sylt") { NSApp.terminate(nil) }
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

/// The island's liquid surface. Always mounted so it animates with the island's own
/// spring; a `LiquidEvent` plays a small ripple on the edge where the pointer went in or out.
private struct Liquid: View, Animatable {
    var shape: IslandShape
    let event: LiquidEvent?
    let strength: Double

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    var body: some View {
        TimelineView(.animation(paused: event == nil)) { context in
            Canvas { graphics, size in
                guard let event else { return }
                let t = context.date.timeIntervalSince(event.start)
                graphics.fill(Ripple.path(in: CGRect(origin: .zero, size: size), shape: shape, origin: event.point, at: t, strength: strength), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A ripple running along the island's rim from where the pointer went in or out, dying
/// out within a few dozen points: the surface bulges outward in a damped wave, never
/// inward, so the content behind is never uncovered. The path is the whole outline,
/// nudged a touch inside where the surface is still, so it only shows where it swells.
private enum Ripple {
    private static let height: CGFloat = 3.6
    private static let step: CGFloat = 1

    static func path(in rect: CGRect, shape: IslandShape, origin: CGPoint, at t: TimeInterval, strength: Double) -> Path {
        let time = CGFloat(t)
        let decay = exp(-2.8 * time)
        guard decay > 0.04 else { return Path() }
        let height = Self.height * CGFloat(strength)
        let outline = shape.outline(in: rect, step: step)
        guard outline.count > 1 else { return Path() }
        var nearest = 0
        var best = CGFloat.greatestFiniteMagnitude
        for (index, sample) in outline.enumerated() {
            let gap = hypot(sample.point.x - origin.x, sample.point.y - origin.y)
            if gap < best { best = gap; nearest = index }
        }
        var path = Path()
        for (index, sample) in outline.enumerated() {
            let distance = CGFloat(abs(index - nearest)) * step
            let wave = sin(distance / 9 - time * 18) * exp(-distance / 24)
            let swell = max(0, wave) * height * decay - 0.5
            let point = CGPoint(x: sample.point.x + sample.normal.dx * swell, y: sample.point.y + sample.normal.dy * swell)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The island as thick dark glass: when the pointer leaves, light catches the rim there
/// and a soft reflection sweeps back across the surface, away from the exit, then fades.
private struct GlassFlash: View {
    let shape: IslandShape
    let point: CGPoint
    let direction: CGVector
    @State private var fired = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 220, height: 56)
                .rotationEffect(.radians(atan2(direction.dy, direction.dx) * 0.3))
                .blur(radius: 8)
                .position(x: point.x - direction.dx * (fired ? 150 : 10), y: point.y - direction.dy * (fired ? 60 : 4))
                .opacity(fired ? 0 : 1)
            RimOutline(shape: shape)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .blur(radius: 0.6)
                .mask(
                    Circle()
                        .fill(RadialGradient(colors: [.white, .white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                        .scaleEffect(fired ? 2.4 : 0.6)
                        .position(point)
                )
                .opacity(fired ? 0 : 0.95)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { fired = true } }
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

/// Light has no business on the island's top edge, which is the screen's edge: anything
/// glowing there fades out over the first few points.
private struct FadeTop: ViewModifier {
    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom).frame(height: 12)
                Color.white
            }
        )
    }
}

/// The island's visible outline as an open path: down the left side, around the bottom,
/// up the right side. The top edge sits against the screen's edge and is left out.
private struct RimOutline: Shape {
    var shape: IslandShape

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, sample) in shape.outline(in: rect, step: 2).enumerated() {
            if index == 0 { path.move(to: sample.point) } else { path.addLine(to: sample.point) }
        }
        return path
    }
}

/// The island's edge lighting up where the held pointer would come out, brighter the harder it is pushed.
private struct RimGlow: View {
    let shape: IslandShape
    let point: CGPoint
    let strength: CGFloat

    var body: some View {
        RimOutline(shape: shape)
            .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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
