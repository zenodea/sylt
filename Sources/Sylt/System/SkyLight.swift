import AppKit
import Foundation

/// WindowServer compositor spaces, reached through the private SkyLight framework.
/// A space pinned at the lock-screen level keeps its windows visible over loginwindow,
/// full-screen apps and every desktop; the window itself is still drawn by AppKit.
enum SkyLight {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceSetLevelFn = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Void
    private typealias MoveWindowsFn = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void

    /// Compositor level of the lock screen UI; a space here draws over loginwindow.
    private static let lockScreenLevel: Int32 = 400
    private static let removeFromAllSpaces: Int32 = 7

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: type)
    }

    private static let mainConnection = symbol("SLSMainConnectionID", as: MainConnectionFn.self)
    private static let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreateFn.self)
    private static let spaceSetLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetLevelFn.self)
    private static let showSpaces = symbol("SLSShowSpaces", as: ShowSpacesFn.self)
    private static let moveWindows = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: MoveWindowsFn.self)

    private static let overlay: (connection: Int32, space: UInt64)? = {
        guard let mainConnection, let spaceCreate, let spaceSetLevel, let showSpaces else { return nil }
        let connection = mainConnection()
        let space = spaceCreate(connection, 1, nil)
        guard space != 0, spaceSetLevel(connection, space, lockScreenLevel) == 0 else { return nil }
        showSpaces(connection, [space] as CFArray)
        return (connection, space)
    }()

    /// Moves the window into the lock-screen-level space. Returns false when SkyLight is unavailable.
    @discardableResult
    static func pinAboveLockScreen(_ window: NSWindow) -> Bool {
        guard let overlay, let moveWindows, window.windowNumber > 0 else { return false }
        moveWindows(overlay.connection, overlay.space, [window.windowNumber] as CFArray, removeFromAllSpaces)
        return true
    }
}
