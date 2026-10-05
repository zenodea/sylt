import AVFoundation
import Combine
import CoreAudio

/// Whether the microphone or a camera is in use by any app.
@MainActor
final class PrivacyMonitor: ObservableObject {
    struct Use: Hashable {
        var microphone = false
        var camera = false

        var any: Bool { microphone || camera }
    }

    @Published var use = Use()
    let changes = PassthroughSubject<Use, Never>()

    private var timer: Timer?
    private var cameras: [AVCaptureDevice] = []

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

    private func refresh(notify: Bool) {
        let current = Use(microphone: Self.microphoneRunning(), camera: cameras.contains { $0.isInUseByAnotherApplication })
        guard current != use else { return }
        use = current
        if notify { changes.send(current) }
    }

    /// A process with input running is a process recording. Asking devices instead
    /// misfires: a headset playing music reports as running though its mic is idle.
    private static func microphoneRunning() -> Bool {
        var listAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &size) == noErr else { return false }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &size, &processes) == noErr else { return false }
        return processes.contains { process in
            var running = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningInput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyData(process, &running, 0, nil, &valueSize, &value) == noErr && value != 0
        }
    }
}
