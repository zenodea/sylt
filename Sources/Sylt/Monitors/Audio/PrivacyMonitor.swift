import AVFoundation
import Combine
import CoreAudio

/// Whether the microphone or a camera is in use by any app.
@MainActor
final class PrivacyMonitor: ObservableObject {
    struct Use: Hashable {
        var microphone = false
        var camera = false
        /// Bundle identifier of the app recording, when known.
        var microphoneApp: String?

        var any: Bool { microphone || camera }
    }

    @Published private(set) var use = Use()
    let changes = PassthroughSubject<Use, Never>()

    private var timer: Timer?
    private var cameras: [AVCaptureDevice] = []
    private var pending: Use?

    func start() {
        guard timer == nil else { return }
        cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified).devices
        refresh(notify: false)
        timer = .every(1.5) { [weak self] in self?.refresh(notify: true) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        use = Use()
    }

    /// A change has to hold for two polls in a row: apps probe the microphone for an
    /// instant when they start, which is not a recording.
    private func refresh(notify: Bool) {
        let recording = Self.recordingApp()
        let current = Use(microphone: recording != nil, camera: cameras.contains { $0.isInUseByAnotherApplication }, microphoneApp: recording?.bundle)
        guard current != use else { pending = nil; return }
        guard notify else { use = current; return }
        guard pending == current else { pending = current; return }
        pending = nil
        use = current
        changes.send(current)
    }

    /// The process with input running is the one recording. Asking devices instead
    /// misfires: a headset playing music reports as running though its mic is idle.
    private static func recordingApp() -> (pid: pid_t, bundle: String?)? {
        for process in processObjects() {
            guard value(of: kAudioProcessPropertyIsRunningInput, on: process, as: UInt32(0)) ?? 0 != 0 else { continue }
            let pid = value(of: kAudioProcessPropertyPID, on: process, as: pid_t(0)) ?? 0
            guard pid != ProcessInfo.processInfo.processIdentifier else { continue }
            let bundle = value(of: kAudioProcessPropertyBundleID, on: process, as: "" as CFString).map { $0 as String }
            return (pid, bundle?.isEmpty == false ? bundle : nil)
        }
        return nil
    }

    private static func value<T>(of selector: AudioObjectPropertySelector, on object: AudioObjectID, as zero: T) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value = zero
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func processObjects() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &processes) == noErr else { return [] }
        return processes
    }
}
