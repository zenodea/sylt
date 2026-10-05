import AppKit

enum Sounds {
    static func unlock() {
        NSSound(named: "Glass")?.play()
    }

    static func play(_ name: String) {
        NSSound(named: name)?.play()
    }
}
