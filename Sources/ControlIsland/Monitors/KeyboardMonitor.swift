import AppKit
import Carbon
import Combine

/// Caps Lock toggles and keyboard layout switches.
@MainActor
final class KeyboardMonitor: ObservableObject {
    let capsLock = PassthroughSubject<Bool, Never>()
    let inputSource = PassthroughSubject<String, Never>()

    private var monitors: [Any] = []
    private var observer: NSObjectProtocol?
    private var caps = NSEvent.modifierFlags.contains(.capsLock)
    private var source = KeyboardMonitor.currentInputSource()

    func start() {
        guard monitors.isEmpty else { return }
        let handle: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor in self?.flagsChanged(event.modifierFlags) }
        }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handle) as Any,
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in handle(event); return event } as Any,
        ]
        observer = DistributedNotificationCenter.default().addObserver(
            forName: .init(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.inputSourceChanged() }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        observer.map(DistributedNotificationCenter.default().removeObserver)
        observer = nil
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        let on = flags.contains(.capsLock)
        guard on != caps else { return }
        caps = on
        capsLock.send(on)
    }

    private func inputSourceChanged() {
        let name = Self.currentInputSource()
        guard name != source else { return }
        source = name
        inputSource.send(name)
    }

    private static func currentInputSource() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
