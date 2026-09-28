extension ScriptedPlayer {
    enum Command {
        case playPause, next, previous, seek(Double)
    }

    func script(for command: Command) -> String {
        let verb: String
        switch command {
        case .playPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        case .seek(let seconds): verb = "set player position to \(seconds)"
        }
        return "tell application id \"\(rawValue)\" to \(verb)"
    }
}
