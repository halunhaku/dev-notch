import Combine
import Foundation

@MainActor
final class NowPlayingStore: ObservableObject {
    @Published private(set) var info: NowPlayingInfo = .empty

    private let client = MediaRemoteClient()
    private var timer: AnyCancellable?
    private var inFlight = false
    private var emptyStreak = 0

    init() {
        refresh()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] in
                _ = $0
                self?.refresh()
            }
    }

    func refresh() {
        guard !inFlight else { return }
        inFlight = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight = false }
            let next = await client.fetch()
            if next.hasTrack {
                emptyStreak = 0
                if next != info { info = next }
            } else {
                emptyStreak += 1
                if emptyStreak >= 2, info.hasTrack {
                    info = .empty
                }
            }
        }
    }

    func togglePlayPause() {
        if info.hasTrack {
            var next = info
            next.elapsed = info.currentElapsed()
            next.timestamp = Date()
            next.isPlaying.toggle()
            next.playbackRate = next.isPlaying ? max(info.playbackRate, 1) : 0
            info = next
        }
        client.send(.togglePlayPause)
        refresh()
    }

    func nextTrack() {
        client.send(.nextTrack)
        refresh()
    }

    func previousTrack() {
        client.send(.previousTrack)
        refresh()
    }
}
