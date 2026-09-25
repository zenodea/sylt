import Foundation
import CoreAudio
import AudioToolbox
import Combine

@MainActor
final class VolumeMonitor: ObservableObject {
    @Published private(set) var level: Float = 0   // 0...1
    @Published private(set) var isMuted = false
    let changes = PassthroughSubject<Void, Never>()

    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var suppressNext = false

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

    func start() {
        attachToDefaultDevice()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.attachToDefaultDevice() }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main, block)
    }

    private func attachToDefaultDevice() {
        if deviceID != kAudioObjectUnknown, let old = listenerBlock {
            AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, .main, old)
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, .main, old)
        }
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &id)
        deviceID = id
        guard id != kAudioObjectUnknown else { return }

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
        if notify {
            if suppressNext { suppressNext = false } else { changes.send() }
        }
    }

    /// Sets the output volume (0...1) without triggering the HUD.
    func set(_ value: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        var v = Float32(min(max(value, 0), 1))
        suppressNext = true
        AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        level = v
    }
}
