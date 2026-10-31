import Combine
import Foundation

@MainActor
final class FirefoxAccess: ObservableObject {
    static let shared = FirefoxAccess()

    @Published private(set) var isDenied = false

    nonisolated static func report(_ error: Error) {
        let code = (error as NSError).code
        update(denied: code == NSFileReadNoPermissionError || code == Int(EPERM))
    }

    nonisolated static func reportSuccess() {
        update(denied: false)
    }

    private nonisolated static func update(denied: Bool) {
        Task { @MainActor in if shared.isDenied != denied { shared.isDenied = denied } }
    }
}
