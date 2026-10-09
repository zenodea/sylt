/// Players whose state is read directly over AppleScript, because MediaRemote
/// withholds their metadata and artwork from non-entitled processes.
enum ScriptedPlayer: String, CaseIterable {
    case spotify = "com.spotify.client"
    case music = "com.apple.Music"

    var snapshotScript: String {
        switch self {
        case .spotify:
            """
            tell application id "com.spotify.client"
                if player state is stopped then return {}
                set t to current track
                return {name of t, artist of t, album of t, (duration of t) / 1000, player position, player state as string, sound volume}
            end tell
            """
        case .music:
            """
            tell application id "com.apple.Music"
                if player state is stopped then return {}
                set t to current track
                return {name of t, artist of t, album of t, duration of t, player position, player state as string, sound volume}
            end tell
            """
        }
    }
}
