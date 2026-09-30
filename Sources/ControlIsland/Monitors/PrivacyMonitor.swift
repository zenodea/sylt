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

    @Published private(set) var use = Use()
    let changes = PassthroughSubject<Use, Never>()

    private var timer: Timer?
    private var cameras: [AVCaptureDevice] = []

    func start() {
        guard timer == nil else { return }
        cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified).devices
        refresh(notify: false)
        timer = .scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(notify: true) }
        }
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

    private static func microphoneRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return false }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return false }
        return devices.contains { device in
            var inputs = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &inputs, 0, nil, &inputSize) == noErr, inputSize > MemoryLayout<UInt32>.size else { return false }
            var running = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyData(device, &running, 0, nil, &valueSize, &value) == noErr && value != 0
        }
    }
}
