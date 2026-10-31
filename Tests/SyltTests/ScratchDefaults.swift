import XCTest

extension XCTestCase {
    func scratchDefaults() -> UserDefaults {
        let suite = "SyltTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }
}
