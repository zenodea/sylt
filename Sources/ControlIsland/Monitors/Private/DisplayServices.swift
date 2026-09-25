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

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: type)
    }

    private static let getFn = symbol("DisplayServicesGetBrightness", as: GetFn.self)
    private static let setFn = symbol("DisplayServicesSetBrightness", as: SetFn.self)
    private static let canFn = symbol("DisplayServicesCanChangeBrightness", as: CanFn.self)
    private static let registerFn = symbol(
        "DisplayServicesRegisterForBrightnessChangeNotifications", as: RegisterFn.self)

    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static func canChangeBrightness(_ display: CGDirectDisplayID) -> Bool {
        canFn?(display) ?? false
    }

    static func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard getFn?(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    static func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        setFn?(display, value) == 0
    }

    @discardableResult
    static func observeBrightness(of display: CGDirectDisplayID, _ callback: ChangeCallback) -> Bool {
        registerFn?(display, display, callback) == 0
    }
}
