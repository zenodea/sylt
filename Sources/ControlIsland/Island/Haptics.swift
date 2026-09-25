import AppKit

enum Haptics {
    static func peek() { perform(.alignment) }
    static func expand() { perform(.levelChange) }
    static func collapse() { perform(.generic) }

    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
