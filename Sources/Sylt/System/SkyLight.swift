import AppKit

enum SkyLight {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceSetLevelFn = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Void
    private typealias MoveWindowsFn = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void

    private static let lockScreenLevel: Int32 = 400
    private static let removeFromAllSpaces: Int32 = 7

    private static let framework = PrivateFramework(private: "SkyLight")
    private static let mainConnection = framework.symbol("SLSMainConnectionID", as: MainConnectionFn.self)
    private static let spaceCreate = framework.symbol("SLSSpaceCreate", as: SpaceCreateFn.self)
    private static let spaceSetLevel = framework.symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetLevelFn.self)
    private static let showSpaces = framework.symbol("SLSShowSpaces", as: ShowSpacesFn.self)
    private static let moveWindows = framework.symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: MoveWindowsFn.self)

    private static let overlay: (connection: Int32, space: UInt64)? = {
        guard let mainConnection, let spaceCreate, let spaceSetLevel, let showSpaces else { return nil }
        let connection = mainConnection()
        let space = spaceCreate(connection, 1, nil)
        guard space != 0, spaceSetLevel(connection, space, lockScreenLevel) == 0 else { return nil }
        showSpaces(connection, [space] as CFArray)
        return (connection, space)
    }()

    static func pinAboveLockScreen(_ window: NSWindow) {
        guard let overlay, let moveWindows, window.windowNumber > 0 else { return }
        moveWindows(overlay.connection, overlay.space, [window.windowNumber] as CFArray, removeFromAllSpaces)
    }
}
