import AudioToolbox
import Combine
import CoreAudio
import Foundation

@MainActor
final class VolumeMonitor: ObservableObject {
    struct OutputDevice: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
    }

    @Published private(set) var level: Float = 0
    @Published private(set) var isMuted = false
    @Published private(set) var outputName = ""
    @Published private(set) var outputIsBluetooth = false
    @Published private(set) var outputs: [OutputDevice] = []
    let changes = PassthroughSubject<Void, Never>()
    let muteChanges = PassthroughSubject<Bool, Never>()

    private var reportedMute = false
    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var deviceBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceBlock: AudioObjectPropertyListenerBlock?
    private var devicesBlock: AudioObjectPropertyListenerBlock?

    private static let volume = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private static let mute = kAudioDevicePropertyMute
    private static let output = kAudioDevicePropertyScopeOutput

    func start() {
        guard defaultDeviceBlock == nil else { return }
        attachToDefaultDevice()
        let defaultDevice: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.attachToDefaultDevice() }
        }
        defaultDeviceBlock = defaultDevice
        AudioObjectID.system.addListener(kAudioHardwarePropertyDefaultOutputDevice, defaultDevice)
        let devices: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refreshOutputs() }
        }
        devicesBlock = devices
        AudioObjectID.system.addListener(kAudioHardwarePropertyDevices, devices)
        refreshOutputs()
    }

    func stop() {
        detachFromDevice()
        if let defaultDeviceBlock { AudioObjectID.system.removeListener(kAudioHardwarePropertyDefaultOutputDevice, defaultDeviceBlock) }
        if let devicesBlock { AudioObjectID.system.removeListener(kAudioHardwarePropertyDevices, devicesBlock) }
        defaultDeviceBlock = nil
        devicesBlock = nil
        deviceID = kAudioObjectUnknown
    }

    func selectOutput(_ id: AudioDeviceID) {
        AudioObjectID.system.write(kAudioHardwarePropertyDefaultOutputDevice, id)
    }

    /// Sets the output volume (0...1) without triggering the HUD.
    func set(_ value: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        let clamped = Float32(min(max(value, 0), 1))
        deviceID.write(Self.volume, scope: Self.output, clamped)
        level = clamped
    }

    func step(_ delta: Float) {
        if isMuted, delta > 0 { setMuted(false) }
        set(level + delta)
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    private func setMuted(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown, deviceID.has(Self.mute, scope: Self.output) else { return }
        deviceID.write(Self.mute, scope: Self.output, UInt32(muted ? 1 : 0))
        isMuted = muted
    }

    private func refreshOutputs() {
        let found = AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioDeviceID(0))
            .filter { !$0.readArray(kAudioDevicePropertyStreams, scope: Self.output, of: AudioStreamID(0)).isEmpty }
            .map { OutputDevice(id: $0, name: $0.readString(kAudioObjectPropertyName) ?? "Output") }
        if found != outputs { outputs = found }
    }

    private func attachToDefaultDevice() {
        detachFromDevice()
        let id = AudioObjectID.system.read(kAudioHardwarePropertyDefaultOutputDevice, as: AudioDeviceID(kAudioObjectUnknown)) ?? kAudioObjectUnknown
        deviceID = id
        guard id != kAudioObjectUnknown else { return }
        outputName = id.readString(kAudioObjectPropertyName) ?? outputName
        let transport = id.read(kAudioDevicePropertyTransportType, as: UInt32(0))
        outputIsBluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.read(notify: true) }
        }
        deviceBlock = block
        id.addListener(Self.volume, scope: Self.output, block)
        id.addListener(Self.mute, scope: Self.output, block)
        read(notify: false)
    }

    private func detachFromDevice() {
        guard deviceID != kAudioObjectUnknown, let deviceBlock else { return }
        deviceID.removeListener(Self.volume, scope: Self.output, deviceBlock)
        deviceID.removeListener(Self.mute, scope: Self.output, deviceBlock)
        self.deviceBlock = nil
    }

    private func read(notify: Bool) {
        if let volume = deviceID.read(Self.volume, scope: Self.output, as: Float32(0)) { level = volume }
        if deviceID.has(Self.mute, scope: Self.output), let mute = deviceID.read(Self.mute, scope: Self.output, as: UInt32(0)) {
            isMuted = mute != 0
        }
        guard notify else { reportedMute = isMuted; return }
        if isMuted != reportedMute {
            reportedMute = isMuted
            muteChanges.send(isMuted)
        } else {
            changes.send()
        }
    }
}
