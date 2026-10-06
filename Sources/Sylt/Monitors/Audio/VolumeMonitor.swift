import Foundation
import CoreAudio
import AudioToolbox
import Combine

@MainActor
final class VolumeMonitor: ObservableObject {
    @Published private(set) var level: Float = 0   // 0...1
    @Published private(set) var isMuted = false
    @Published private(set) var outputName = ""
    @Published private(set) var outputIsBluetooth = false
    @Published private(set) var outputs: [OutputDevice] = []

    struct OutputDevice: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
    }
    let changes = PassthroughSubject<Void, Never>()
    let muteChanges = PassthroughSubject<Bool, Never>()
    private var reportedMute = false

    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceBlock: AudioObjectPropertyListenerBlock?

    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private var devicesBlock: AudioObjectPropertyListenerBlock?

    func start() {
        guard defaultDeviceBlock == nil else { return }
        attachToDefaultDevice()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.attachToDefaultDevice() }
        }
        defaultDeviceBlock = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main, block)
        let devices: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refreshOutputs() }
        }
        devicesBlock = devices
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, devices)
        refreshOutputs()
    }

    /// Every device that can play sound, for the output picker.
    private func refreshOutputs() {
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, 0, nil, &size) == noErr else { return }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, 0, nil, &size, &ids) == noErr else { return }
        let found = ids.compactMap { id -> OutputDevice? in
            var streams = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            return OutputDevice(id: id, name: Self.name(of: id))
        }
        if found != outputs { outputs = found }
    }

    /// Make this device the system's output; the volume follows it through the listener.
    func selectOutput(_ id: AudioDeviceID) {
        var device = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &device)
    }

    private static func name(of id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr ? name as String : "Output"
    }

    private static func isBluetooth(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport) == noErr else { return false }
        return transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    func stop() {
        detachFromDevice()
        if let defaultDeviceBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main, defaultDeviceBlock)
        }
        defaultDeviceBlock = nil
        if let devicesBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, devicesBlock)
        }
        devicesBlock = nil
        deviceID = kAudioObjectUnknown
    }

    private func detachFromDevice() {
        guard deviceID != kAudioObjectUnknown, let listenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, .main, listenerBlock)
        AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, .main, listenerBlock)
        self.listenerBlock = nil
    }

    private func attachToDefaultDevice() {
        detachFromDevice()
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &id)
        deviceID = id
        guard id != kAudioObjectUnknown else { return }
        var name = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        if AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name) == noErr {
            outputName = name as String
        }
        outputIsBluetooth = Self.isBluetooth(id)

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.read(notify: true) }
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(id, &volumeAddress, .main, block)
        AudioObjectAddPropertyListenerBlock(id, &muteAddress, .main, block)
        read(notify: false)
    }

    private func read(notify: Bool) {
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &vol) == noErr {
            level = vol
        }
        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectHasProperty(deviceID, &muteAddress),
           AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &mute) == noErr {
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

    /// Sets the output volume (0...1) without triggering the HUD.
    func set(_ value: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        var clamped = Float32(min(max(value, 0), 1))
        AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &clamped)
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
        guard deviceID != kAudioObjectUnknown, AudioObjectHasProperty(deviceID, &muteAddress) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        isMuted = muted
    }
}
