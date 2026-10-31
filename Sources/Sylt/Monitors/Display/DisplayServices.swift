import CoreGraphics
import Foundation

enum DisplayServices {
    typealias ChangeCallback = @convention(c) (
        CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?
    ) -> Void

    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanFn = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias RegisterFn = @convention(c) (CGDirectDisplayID, CGDirectDisplayID, ChangeCallback) -> Int32

    private static let framework = PrivateFramework(private: "DisplayServices")
    private static let getFn = framework.symbol("DisplayServicesGetBrightness", as: GetFn.self)
    private static let setFn = framework.symbol("DisplayServicesSetBrightness", as: SetFn.self)
    private static let canFn = framework.symbol("DisplayServicesCanChangeBrightness", as: CanFn.self)
    private static let registerFn = framework.symbol("DisplayServicesRegisterForBrightnessChangeNotifications", as: RegisterFn.self)

    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static func canChangeBrightness(_ display: CGDirectDisplayID) -> Bool {
        canFn?(display) ?? false
    }

    static func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard getFn?(display, &value) == 0 else { return nil }
        return value
    }

    static func setBrightness(_ value: Float, of display: CGDirectDisplayID) {
        _ = setFn?(display, value)
    }

    static func observeBrightness(of display: CGDirectDisplayID, _ callback: ChangeCallback) -> Bool {
        registerFn?(display, display, callback) == 0
    }
}
