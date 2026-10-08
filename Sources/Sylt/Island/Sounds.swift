import AppKit

enum Sounds {
    static func unlock() { play("Glass") }
    static func lock() { play("Tink") }

    static func play(_ name: String) {
        NSSound(named: name)?.play()
    }
}
