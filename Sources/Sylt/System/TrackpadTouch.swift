import Foundation

@MainActor
final class TrackpadTouch {
    static let shared = TrackpadTouch()

    private(set) var isTouching = false
    var onChange: ((Bool) -> Void)?

    private typealias Device = UnsafeMutableRawPointer
    private typealias Callback = @convention(c) (Device?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>
    private typealias Register = @convention(c) (Device, Callback) -> Void
    private typealias Start = @convention(c) (Device, Int32) -> Void

    private nonisolated(unsafe) static var fingers: Int32 = 0
    private var devices: [AnyObject] = []

    func start() {
        guard devices.isEmpty else { return }
        let framework = PrivateFramework(private: "MultitouchSupport")
        guard let createList = framework.symbol("MTDeviceCreateList", as: CreateList.self),
              let register = framework.symbol("MTRegisterContactFrameCallback", as: Register.self),
              let startDevice = framework.symbol("MTDeviceStart", as: Start.self)
        else { return }
        devices = createList().takeRetainedValue() as [AnyObject]
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
            register(reference, callback)
            startDevice(reference, 0)
        }
    }

    private func contactChanged(_ touching: Bool) {
        isTouching = touching
        onChange?(touching)
    }
}
