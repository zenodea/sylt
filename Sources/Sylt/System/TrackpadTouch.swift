import Foundation

/// Whether a finger is on the built-in trackpad, from the private MultitouchSupport
/// framework. Mouse events can't say when the hand lets go; contact frames can.
@MainActor
final class TrackpadTouch {
    static let shared = TrackpadTouch()

    private(set) var isTouching = false
    /// Called on the main thread whenever contact starts or ends.
    var onChange: ((Bool) -> Void)?
    private(set) var isAvailable = false

    private typealias Device = UnsafeMutableRawPointer
    private typealias Callback = @convention(c) (Device?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>
    private typealias Register = @convention(c) (Device, Callback) -> Void
    private typealias Start = @convention(c) (Device, Int32) -> Void

    private nonisolated(unsafe) static var fingers: Int32 = 0
    private var devices: [AnyObject] = []

    func start() {
        guard devices.isEmpty,
              let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let createList = dlsym(handle, "MTDeviceCreateList"),
              let register = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startDevice = dlsym(handle, "MTDeviceStart")
        else { return }
        devices = unsafeBitCast(createList, to: CreateList.self)().takeRetainedValue() as [AnyObject]
        let callback: Callback = { _, _, count, _, _ in
            guard count != TrackpadTouch.fingers else { return 0 }
            let wasTouching = TrackpadTouch.fingers > 0
            TrackpadTouch.fingers = count
            if (count > 0) != wasTouching {
                DispatchQueue.main.async { TrackpadTouch.shared.contactChanged(count > 0) }
            }
            return 0
        }
        for device in devices {
            let reference = Unmanaged.passUnretained(device).toOpaque()
            unsafeBitCast(register, to: Register.self)(reference, callback)
            unsafeBitCast(startDevice, to: Start.self)(reference, 0)
        }
        isAvailable = !devices.isEmpty
    }

    private func contactChanged(_ touching: Bool) {
        isTouching = touching
        onChange?(touching)
    }
}
