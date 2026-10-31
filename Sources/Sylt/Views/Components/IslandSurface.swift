import AppKit
import SwiftUI

struct IslandSurface: View, Animatable {
    var shape: IslandShape
    let notch: CGSize
    let glass: GlassStates
    let tint: Color
    let frosted: Bool
    let liquid: Bool
    let ripple: (event: LiquidEvent?, strength: Double, width: Double)

    private var playsRipple: Bool { frosted && liquid }

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    // Read from the shape's animated size: a spring of its own overshot as the island opened.
    private var openness: CGFloat {
        guard glass.followsSize else { return 0 }
        func progress(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
            guard range.upperBound - range.lowerBound > 1 else { return 0 }
            return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
        }
        return max(progress(shape.frame.size.height, glass.heights), progress(shape.frame.size.width, glass.widths))
    }

    private var reach: CGSize {
        CGSize(width: blend(glass.closed.reach.width, glass.open.reach.width), height: blend(glass.closed.reach.height, glass.open.reach.height))
    }

    private var opacity: Double { blend(glass.closed.opacity, glass.open.opacity) }
    private var blur: Double { blend(glass.closed.blur, glass.open.blur) }

    private func blend<Value: BinaryFloatingPoint>(_ closed: Value, _ open: Value) -> Value {
        closed + (open - closed) * Value(openness)
    }

    var body: some View {
        if frosted {
            let event = playsRipple ? ripple.event : nil
            TimelineView(.animation(paused: event == nil)) { context in
                GeometryReader { proxy in
                    surface(in: CGRect(origin: .zero, size: proxy.size), at: context.date, event: event)
                }
            }
            .allowsHitTesting(false)
        } else {
            shape.fill(.black)
        }
    }

    private func surface(in rect: CGRect, at date: Date, event: LiquidEvent?) -> some View {
        let size = shape.frame.size
        // Liquid Glass rounds all four corners, so it starts a radius above the screen's edge.
        let overhang = liquid ? shape.cornerRadius : 0
        let margin = playsRipple ? Ripple.reach(strength: ripple.strength) + 1 : 0
        let origin = shape.origin(in: rect)
        let glassOrigin = CGPoint(x: origin.x - margin, y: -overhang)
        let glassSize = CGSize(width: size.width + margin * 2, height: size.height + overhang + margin)
        let drops = event.map { rippleDrops(in: rect, from: $0, at: date, offset: glassOrigin) } ?? []
        let outline = event
            .map { Ripple.path(in: rect, shape: shape, origin: $0.point, at: date.timeIntervalSince($0.start), strength: ripple.strength, width: ripple.width, rest: 0) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? shape.path(in: rect)

        return ZStack(alignment: .topLeading) {
            // Liquid Glass has no blur of its own; a frosted blur underneath frosts it.
            if liquid, blur > 0 {
                FrostedGlass(cornerRadius: shape.cornerRadius, tint: .clear, liquid: false, island: .zero, drops: [])
                    .frame(width: size.width, height: size.height)
                    .offset(x: origin.x)
                    .opacity(opacity * blur)
            }
            FrostedGlass(
                cornerRadius: shape.cornerRadius,
                tint: tint,
                liquid: liquid,
                island: CGRect(x: margin, y: 0, width: size.width, height: size.height + overhang),
                drops: drops
            )
            // The NSView's kind is fixed when it is made, so a change of kind needs a new one.
            .id(liquid)
            .frame(width: glassSize.width, height: glassSize.height)
            .offset(x: glassOrigin.x, y: glassOrigin.y)
            .opacity(opacity)
            if !liquid {
                shape.fill(tint).opacity(opacity)
            }
            // Past the outline, or the glass's bright rim shows through the black's soft edge.
            Color.black
                .mask(alignment: .top) { IslandFalloff(shape: shape, notch: notch, reach: reach, padding: margin + Self.rimCover) }
                .mask {
                    let edge = OutlineShape(path: outline)
                    ZStack {
                        edge.fill()
                        edge.stroke(lineWidth: Self.rimCover * 2)
                    }
                }
            if liquid {
                innerGlow(outline: outline, padding: margin + Self.rimCover).opacity(opacity)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }

    private func rippleDrops(in rect: CGRect, from event: LiquidEvent, at date: Date, offset: CGPoint) -> [CGRect] {
        let rim = Ripple.rim(in: rect, shape: shape, origin: event.point, at: date.timeIntervalSince(event.start), strength: ripple.strength, width: ripple.width, step: Self.dropSpacing)
        return (rim ?? []).filter { $0.swell > Self.dropThreshold }.map { sample in
            let reach = sample.swell - Self.dropSize / 2
            let centre = CGPoint(x: sample.point.x + sample.normal.dx * reach - offset.x, y: sample.point.y + sample.normal.dy * reach - offset.y)
            return CGRect(x: centre.x - Self.dropSize / 2, y: centre.y - Self.dropSize / 2, width: Self.dropSize, height: Self.dropSize)
        }
    }

    private func innerGlow(outline: Path, padding: CGFloat) -> some View {
        let edge = OutlineShape(path: outline)
        let height = max(shape.frame.size.height, 1)
        return edge
            .stroke(.white.opacity(Self.glowStrength), lineWidth: Self.glowDepth * 2)
            .blur(radius: Self.glowDepth / 2)
            .clipShape(edge)
            .mask(alignment: .top) {
                Rectangle()
                    .overlay(alignment: .top) {
                        IslandFalloff(shape: shape, notch: notch, reach: reach, padding: padding).blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .mask(alignment: .top) {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: min(Self.glowDepth * 1.5 / height, 1))],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
            }
    }

    private static let rimCover: CGFloat = 1

    private static let glowDepth: CGFloat = 8
    private static let glowStrength = 0.12

    private static let dropSize: CGFloat = 10
    private static let dropSpacing: CGFloat = 3
    private static let dropThreshold: CGFloat = 0.3
}

private struct OutlineShape: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path { path }
}

private struct FrostedGlass: NSViewRepresentable {
    let cornerRadius: CGFloat
    let tint: Color
    let liquid: Bool
    let island: CGRect
    let drops: [CGRect]

    private static let mergeDistance: CGFloat = 8

    func makeNSView(context: Context) -> NSView {
        if liquid, #available(macOS 26, *) {
            let container = NSGlassEffectContainerView()
            container.spacing = Self.mergeDistance
            let content = FlippedView()
            content.autoresizingMask = [.width, .height]
            container.contentView = content
            content.addSubview(Self.glass())
            return container
        }
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        let radius = cornerRadius.rounded()
        if #available(macOS 26, *), let container = view as? NSGlassEffectContainerView, let content = container.contentView {
            let color = NSColor(tint)
            let tintColor = color.alphaComponent > 0 ? color : nil
            while content.subviews.count < drops.count + 1 {
                content.addSubview(Self.glass())
            }
            for (index, subview) in content.subviews.enumerated() {
                guard let glass = subview as? NSGlassEffectView else { continue }
                let frame = index == 0 ? island : (drops.indices.contains(index - 1) ? drops[index - 1] : nil)
                glass.isHidden = frame == nil
                guard let frame else { continue }
                glass.frame = frame
                glass.cornerRadius = index == 0 ? radius : frame.width / 2
                glass.tintColor = tintColor
            }
        } else if let blur = view as? NSVisualEffectView, blur.maskImage?.capInsets.bottom != radius {
            blur.maskImage = Self.mask(radius: radius)
        }
    }

    @available(macOS 26, *)
    private static func glass() -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .clear
        // The dark look made the strip of glass along the bottom darker than the desktop.
        view.appearance = NSAppearance(named: .aqua)
        return view
    }

    private static func mask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            NSRect(x: 0, y: radius, width: side, height: side - radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

extension View {
    // Glass shows the window's own pixels as well as the desktop, so black beneath it hides the blur.
    func hollowed(by shape: IslandShape, if enabled: Bool) -> some View {
        mask {
            Rectangle()
                .overlay { shape.blendMode(.destinationOut).opacity(enabled ? 1 : 0) }
                .compositingGroup()
        }
    }
}

private struct IslandFalloff: View {
    let shape: IslandShape
    let notch: CGSize
    let reach: CGSize
    let padding: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            edgeFalloff
            notchFalloff
        }
    }

    private var edgeFalloff: some View {
        let size = shape.frame.size
        let width = max(size.width, 1), height = max(size.height, 1)
        let across = min(max(reach.width, 0), 1) * width / 2
        let belowNotch = max(height - notch.height, 0)
        let stopsAtRow = min(belowNotch / Self.rowStopDepth, 1)
        let up = min(max(reach.height, 0), 1) * (height - notch.height * stopsAtRow)
        let (black, clear) = (across / width, max(0, across - Self.edgeSoft.width) / width)
        let sideways = Self.ramp(from: black, to: clear).reversed() + Self.ramp(from: 1 - black, to: 1 - clear)
        let downwards = Self.ramp(from: 1 - up / height, to: 1 - max(0, up - Self.edgeSoft.height) / height)
        let (sideEdge, bottomEdge) = (across > 0 ? 0.0 : 1.0, up > 0 ? 0.0 : 1.0)
        let paddedWidth = width + padding * 2, paddedHeight = height + padding
        let paddedSideways = [Gradient.Stop(color: .black.opacity(sideEdge), location: 0)]
            + sideways.map { Gradient.Stop(color: $0.color, location: (padding + $0.location * width) / paddedWidth) }
            + [Gradient.Stop(color: .black.opacity(sideEdge), location: 1)]
        let paddedDownwards = downwards.map { Gradient.Stop(color: $0.color, location: $0.location * height / paddedHeight) }
            + [Gradient.Stop(color: .black.opacity(bottomEdge), location: 1)]
        return Rectangle()
            .fill(LinearGradient(stops: paddedSideways, startPoint: .leading, endPoint: .trailing))
            .mask(LinearGradient(stops: paddedDownwards, startPoint: .top, endPoint: .bottom))
            .frame(width: paddedWidth, height: paddedHeight)
            .offset(x: shape.frame.centerOffset)
    }

    private var notchFalloff: some View {
        let below = max(shape.frame.size.height - notch.height, 0)
        let softBelow = min(Self.notchSoft.height, below)
        let solid = CGSize(width: Self.notchSolid.width, height: min(Self.notchSolid.height, below - softBelow))
        let soft = CGSize(width: Self.notchSoft.width, height: softBelow)
        let size = CGSize(width: notch.width + (solid.width + soft.width) * 2,
                          height: notch.height + solid.height + soft.height)
        let side = soft.width / size.width
        let sideways = Self.ramp(from: side, to: 0).reversed() + Self.ramp(from: 1 - side, to: 1)
        return Rectangle()
            .fill(LinearGradient(stops: sideways, startPoint: .leading, endPoint: .trailing))
            .mask(LinearGradient(stops: Self.ramp(from: (notch.height + solid.height) / max(size.height, 1), to: 1), startPoint: .top, endPoint: .bottom))
            .frame(width: size.width, height: size.height)
    }

    private static let rowStopDepth: CGFloat = 60

    private static let edgeSoft = CGSize(width: 48, height: 20)

    private static let notchSolid = CGSize(width: 12, height: 6)
    private static let notchSoft = CGSize(width: 48, height: 20)

    private static func ramp(from start: CGFloat, to end: CGFloat) -> [Gradient.Stop] {
        stride(from: 0, through: 1, by: 0.125).map { t in
            Gradient.Stop(color: .black.opacity(1 - t * t * (3 - 2 * t)), location: start + (end - start) * t)
        }
    }
}

struct GlassStates {
    struct State {
        var reach: CGSize
        var opacity: Double
        var blur: Double
    }

    let closed: State
    let open: State
    let heights: ClosedRange<CGFloat>
    let widths: ClosedRange<CGFloat>
    let followsSize: Bool
}
