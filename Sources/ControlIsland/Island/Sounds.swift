import AppKit

enum Sounds {
    static func unlock() {
        NSSound(named: "Glass")?.play()
    }
}
