import AVFoundation
import Combine
import CoreAudio

@MainActor
final class PrivacyMonitor: ObservableObject {
    struct Use: Hashable {
        var microphone = false
        var camera = false
        /// Name of the app recording, when known.
        var microphoneApp: String?

        var any: Bool { microphone || camera }

        /// What the overlay says, naming the app recording when known.
        var message: String {
            let app = microphoneApp.map { " · " + $0 } ?? ""
            return switch (microphone, camera) {
            case (true, true): "Mic and camera on" + app
            case (true, false): "Microphone on" + app
            case (false, true): "Camera on"
            case (false, false): "Mic and camera off"
            }
        }
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
        let current = Use(microphone: recording != nil, camera: cameras.contains { $0.isInUseByAnotherApplication }, microphoneApp: bundle.map(AppIcons.name))
        guard current != use else { pending = nil; return }
        guard notify else { use = current; return }
        guard pending == current else { pending = current; return }
        pending = nil
        use = current
        changes.send(current)
        Self.log(current)
    }

    /// One line per change in ~/Library/Logs/Sylt/privacy.log, so a mysterious
    /// indicator can be traced to the app that caused it.
    private static func log(_ use: Use) {
        guard let folder = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/Sylt") else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let line = "\(Date().formatted(.iso8601)) \(use.message)\n"
        let file = folder.appendingPathComponent("privacy.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
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
