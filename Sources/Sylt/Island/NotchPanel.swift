import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    private let state: IslandState
    private let host: IslandHostingView
    private var geometry: NotchGeometry
    private lazy var pointer = PointerCapture(state: state, panel: self)
    private var mouseMonitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastMode = IslandMode.closed

    init(screen: NSScreen, state: IslandState, openSettings: @escaping () -> Void) {
        self.state = state
        self.geometry = NotchGeometry(screen: screen)
        host = IslandHostingView(rootView: IslandView(state: state, openSettings: openSettings))
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        canBecomeVisibleWithoutLogin = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        state.apply(geometry)
        host.state = state
        contentView = host
        applyFrame()
        SkyLight.pinAboveLockScreen(self)
        trackCursor()
    }

    deinit {
        mouseMonitors.forEach(NSEvent.removeMonitor)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var isMeasured: Bool { geometry.isMeasured }

    // Only a real change of screen or notch moves anything; the menu bar sliding in and
    // out also fires a screen change and must not.
    func relayout(on screen: NSScreen) {
        let next = NotchGeometry(screen: screen)
        if next != geometry {
            geometry = next
            state.apply(geometry)
        }
        applyFrame()
    }

    func ensurePlacement() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        if frame != Self.frame(on: screen, size: state.canvasSize) || geometry.screen != screen {
            relayout(on: screen)
            SkyLight.pinAboveLockScreen(self)
            orderFrontRegardless()
        }
    }

    var expandedHome: CGPoint {
        screenPoint(of: state.layout.expandedHome)
    }

    var islandCentre: CGPoint {
        let island = state.layout.rect(of: state.islandFrame)
        return screenPoint(of: CGPoint(x: island.midX, y: island.midY + (state.layout.hasNotch ? 2 : 0)))
    }

    func followPointer() {
        let point = canvasPoint(of: NSEvent.mouseLocation)
        state.cursorMoved(to: point)
        state.cursorApproached(point)
        ignoresMouseEvents = state.lock.isLocked || !state.isHovering
    }

    func screenPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + point.x, y: frame.maxY - point.y)
    }

    func canvasPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
    }

    private func trackCursor() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        mouseMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in self?.routeMouse(event) } as Any,
            NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
                self?.routeMouse(event)
                return event
            } as Any,
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, state.isHovering || pointer.isCaptured else { return event }
                return host.handleScroll(event) ? nil : event
            } as Any,
        ]
        state.lock.$isLocked
            .combineLatest(state.$mode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, mode in
                guard let self else { return }
                if mode == .expanded, lastMode != .expanded, !pointer.isCaptured { CursorControl.warp(to: expandedHome) }
                lastMode = mode
                routeMouse(nil)
            }
            .store(in: &cancellables)
    }

    private func routeMouse(_ event: NSEvent?) {
        if let event, routeMove(event) { return }
        if pointer.isCaptured {
            guard state.absorbsCursor else { return pointer.release(toward: .zero) }
            if let event, event.type == .mouseMoved || event.type == .leftMouseDragged { pointer.dragged(by: event) }
            return
        }
        followPointer()
        // Only an island along the top of the screen has the menu bar to fight with.
        MenuBarGuard.keepAway(NSEvent.mouseLocation, panel: frame, island: state.layout.anchor.flush.contains(.top) ? state.hitFrame : nil)
        if state.absorbsCursor, pointer.canCapture { pointer.capture() }
    }

    /// Command-drag moves the island along the screen's edges. The press is taken here, before
    /// the island's own click handling sees it.
    private func routeMove(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown:
            guard event.modifierFlags.contains(.command), state.canMove,
                  state.hitFrame.contains(canvasPoint(of: NSEvent.mouseLocation)) else { return false }
            if pointer.isCaptured { pointer.release(toward: .zero) }
            state.beginMove()
            return true
        case .leftMouseDragged:
            guard state.isMoving else { return false }
            state.move(to: canvasPoint(of: NSEvent.mouseLocation))
            return true
        case .leftMouseUp:
            guard state.isMoving else { return false }
            state.endMove()
            followPointer()
            return true
        default:
            return false
        }
    }

    private func applyFrame() {
        setFrame(Self.frame(on: geometry.screen, size: state.canvasSize), display: true)
    }

    private static func frame(on screen: NSScreen, size: CGSize) -> NSRect {
        NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height)
    }
}
