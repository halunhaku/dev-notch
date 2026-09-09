import AppKit

/// Fallback when MediaRemote returns empty. Only talks to Music if it is already running.
enum MusicAppleScriptClient {
    static func isMusicRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    static func fetch() -> NowPlayingInfo? {
        guard isMusicRunning() else { return nil }
        let source = """
        tell application "Music"
          if player state is stopped then return "stopped"
          set trackName to name of current track
          set trackArtist to artist of current track
          set trackAlbum to album of current track
          set trackDuration to duration of current track
          set trackPosition to player position
          set trackState to player state as string
          return trackName & tab & trackArtist & tab & trackAlbum & tab & (trackDuration as string) & tab & (trackPosition as string) & tab & trackState
        end tell
        """
        guard let result = run(source), result != "stopped" else { return nil }
        let parts = result.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else { return nil }
        let duration = Double(parts[3]) ?? 0
        let elapsed = Double(parts[4]) ?? 0
        let state = parts[5].lowercased()
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: duration,
            elapsed: elapsed,
            isPlaying: state.contains("play"),
            playbackRate: state.contains("play") ? 1 : 0,
            timestamp: Date(),
            artworkData: nil
        )
    }

    static func send(_ command: NowPlayingCommand) {
        guard isMusicRunning() else { return }
        let verb: String
        switch command {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .togglePlayPause: verb = "playpause"
        case .nextTrack: verb = "next track"
        case .previousTrack: verb = "previous track"
        }
        _ = run("tell application \"Music\" to \(verb)")
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let output = script?.executeAndReturnError(&error)
        if error != nil { return nil }
        return output?.stringValue
    }
}
