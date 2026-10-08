import CoreAudio

extension AudioObjectPropertyAddress {
    init(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) {
        self.init(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func has(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> Bool {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        return AudioObjectHasProperty(self, &address)
    }

    func read<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, as zero: T) -> T? {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        var value = zero
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0) }
        return status == noErr ? value : nil
    }

    func readString(_ selector: AudioObjectPropertySelector) -> String? {
        read(selector, as: "" as CFString).map { $0 as String }
    }

    func readArray<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, of zero: T) -> [T] {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size) == noErr else { return [] }
        var values = [T](repeating: zero, count: Int(size) / MemoryLayout<T>.size)
        guard !values.isEmpty else { return [] }
        let status = values.withUnsafeMutableBufferPointer { AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0.baseAddress!) }
        return status == noErr ? values : []
    }

    func write<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ value: T) {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        withUnsafePointer(to: value) { _ = AudioObjectSetPropertyData(self, &address, 0, nil, UInt32(MemoryLayout<T>.size), $0) }
    }

    func addListener(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ block: @escaping AudioObjectPropertyListenerBlock) {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        AudioObjectAddPropertyListenerBlock(self, &address, .main, block)
    }

    func removeListener(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ block: @escaping AudioObjectPropertyListenerBlock) {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        AudioObjectRemovePropertyListenerBlock(self, &address, .main, block)
    }
}
