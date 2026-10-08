import AVFoundation
import Combine
import CoreAudio

@MainActor
final class PrivacyMonitor: ObservableObject {
    struct Use: Hashable {
        var microphone = false
        var camera = false
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
        let recording = Self.recordingProcess()
        let bundle = recording?.readString(kAudioProcessPropertyBundleID).flatMap { $0.isEmpty ? nil : $0 }
        let current = Use(microphone: recording != nil, camera: cameras.contains { $0.isInUseByAnotherApplication }, microphoneApp: bundle)
        guard current != use else { pending = nil; return }
        guard notify else { use = current; return }
        guard pending == current else { pending = current; return }
        pending = nil
        use = current
        changes.send(current)
    }

    /// The process with input running is the one recording. Asking devices instead
    /// misfires: a headset playing music reports as running though its mic is idle.
    private static func recordingProcess() -> AudioObjectID? {
        let own = ProcessInfo.processInfo.processIdentifier
        return AudioObjectID.system.readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID(0)).first { process in
            process.read(kAudioProcessPropertyIsRunningInput, as: UInt32(0)) ?? 0 != 0
                && process.read(kAudioProcessPropertyPID, as: pid_t(0)) != own
        }
    }
}
