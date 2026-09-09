import Foundation

struct NowPlayingInfo: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsed: TimeInterval
    var isPlaying: Bool
    var playbackRate: Double
    var timestamp: Date
    var artworkData: Data?
    var sourceAppName: String = ""
    var sourceBundleIdentifier: String = ""

    static let empty = NowPlayingInfo(
        title: "",
        artist: "",
        album: "",
        duration: 0,
        elapsed: 0,
        isPlaying: false,
        playbackRate: 0,
        timestamp: .distantPast,
        artworkData: nil
    )

    var hasTrack: Bool {
        !title.isEmpty || !artist.isEmpty
    }

    var displayTitle: String {
        title.isEmpty ? "Unknown Title" : title
    }

    var displayArtist: String {
        artist.isEmpty ? "Unknown Artist" : artist
    }

    func currentElapsed(at now: Date = Date()) -> TimeInterval {
        guard duration > 0 else { return max(0, elapsed) }
        var value = elapsed
        if isPlaying, timestamp > .distantPast {
            let rate = playbackRate > 0 ? playbackRate : 1
            value += now.timeIntervalSince(timestamp) * rate
        }
        return min(duration, max(0, value))
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentElapsed() / duration))
    }
}

enum NowPlayingCommand: UInt32, Equatable, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}
