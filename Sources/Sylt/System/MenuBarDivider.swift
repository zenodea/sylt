import AppKit
import Combine

@MainActor
final class MenuBarDivider: ObservableObject {
    @Published private(set) var isHiding = false
    @Published private(set) var isActive = false

    var revealsOnHover = false { didSet { watchPointer() } }

    private var control: NSStatusItem?
    private var divider: NSStatusItem?
    private var pointer: Timer?
    private var rehide: Timer?
    private var fit: Timer?
    private var revealedByPointer = false

    private static let controlName = "divider.control"
    private static let dividerName = "divider.bar"
    // From the screen's right edge: just left of Apple's own items, so third-party ones hide.
    private static let controlPosition: Double = 130
    private static let dividerPosition: Double = 150
    private static let dividerLength: CGFloat = 14
    private static let notchClearance: CGFloat = 12
    private static let fitStep: CGFloat = 30
    private static let menuBarHeight: CGFloat = 24
    private static let rehideDelay: TimeInterval = 1.5

    func start() {
        guard control == nil else { return }
        Self.seedPositions()
        let control = NSStatusBar.system.statusItem(withLength: 22)
        control.autosaveName = Self.controlName
        control.button?.target = self
        control.button?.action = #selector(toggle)
        self.control = control
        let divider = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        divider.autosaveName = Self.dividerName
        divider.button?.image = NSImage(systemSymbolName: "poweron", accessibilityDescription: "Divider")
        divider.button?.alphaValue = 0.5
        self.divider = divider
        isActive = true
        // The item's place on the bar is known only once it has been laid out.
        Timer.after(0.3) { [weak self] in self?.hide(true) }
        watchPointer()
    }

    // AppKit reads an item's position from these defaults only when the item is created.
    private static func seedPositions() {
        if UserDefaults.standard.object(forKey: positionKey(controlName)) == nil { write(position: controlPosition) }
    }

    private static func write(position: Double) {
        let defaults = UserDefaults.standard
        defaults.set(position, forKey: positionKey(controlName))
        defaults.set(position + dividerPosition - controlPosition, forKey: positionKey(dividerName))
        defaults.set(true, forKey: "NSStatusItem Visible \(controlName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(dividerName)")
    }

    private static func positionKey(_ name: String) -> String {
        "NSStatusItem Preferred Position \(name)"
    }

    func stop() {
        [control, divider].compactMap { $0 }.forEach(NSStatusBar.system.removeStatusItem)
        control = nil
        divider = nil
        pointer?.invalidate()
        pointer = nil
        cancelRehide()
        fit?.invalidate()
        fit = nil
        isHiding = false
        isActive = false
    }

    // macOS refuses a length it cannot fit, so the request shrinks until one is taken.
    func hide(_ hidden: Bool) {
        guard let divider, let control else { return }
        control.button?.image = NSImage(systemSymbolName: hidden ? "chevron.left" : "chevron.right", accessibilityDescription: hidden ? "Show hidden items" : "Hide items")
        isHiding = hidden
        fit?.invalidate()
        fit = nil
        guard hidden else { divider.length = Self.dividerLength; return }
        grow(to: hiddenLength)
    }

    private func grow(to length: CGFloat) {
        guard let divider, isHiding, length > Self.dividerLength else { divider?.length = Self.dividerLength; return }
        divider.length = length
        fit = .after(0.15) { [weak self] in
            guard let self, let width = divider.button?.window?.frame.width else { return }
            if width < length - 2 { grow(to: length - Self.fitStep) }
        }
    }

    private var hiddenLength: CGFloat {
        guard let frame = divider?.button?.window?.frame, let screen = NSScreen.screens.first(where: { $0.frame.contains(frame.origin) }) ?? NSScreen.screens.first else { return Self.dividerLength }
        return frame.maxX - (screen.frame.midX + (screen.notchWidth ?? 0) / 2) - Self.notchClearance
    }

    var position: Double {
        UserDefaults.standard.object(forKey: Self.positionKey(Self.controlName)) as? Double ?? Self.controlPosition
    }

    func move(to position: Double) {
        let wasActive = isActive
        stop()
        Self.write(position: position)
        if wasActive { start() }
    }

    @objc private func toggle() {
        revealedByPointer = false
        cancelRehide()
        hide(!isHiding)
    }

    private func watchPointer() {
        pointer?.invalidate()
        pointer = nil
        guard isActive, revealsOnHover else { return }
        pointer = .every(0.2) { [weak self] in self?.pointerMoved() }
    }

    private func pointerMoved() {
        guard let screen = NSScreen.screens.first else { return }
        let inMenuBar = NSEvent.mouseLocation.y >= screen.frame.maxY - Self.menuBarHeight && screen.frame.contains(CGPoint(x: NSEvent.mouseLocation.x, y: screen.frame.maxY - 1))
        if inMenuBar, isHiding {
            revealedByPointer = true
            cancelRehide()
            hide(false)
        } else if !inMenuBar, revealedByPointer, rehide == nil {
            rehide = .after(Self.rehideDelay) { [weak self] in
                self?.rehide = nil
                self?.revealedByPointer = false
                self?.hide(true)
            }
        } else if inMenuBar {
            cancelRehide()
        }
    }

    private func cancelRehide() {
        rehide?.invalidate()
        rehide = nil
    }
}
