import AppKit

enum Sounds {
    static func unlock() {
        NSSound(named: "Glass")?.play()
    }

    static func timer() {
        NSSound(named: "Hero")?.play()
    }
}
