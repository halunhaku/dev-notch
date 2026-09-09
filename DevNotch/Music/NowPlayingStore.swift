import AppKit
import Combine
import Foundation

struct NowPlayingQueueTrack: Equatable, Sendable {
    var title: String
    var artist: String
    var duration: TimeInterval
}

@MainActor
final class NowPlayingStore: ObservableObject {
    @Published private(set) var info: NowPlayingInfo = .empty
    @Published var volume: Double = 0.5
    @Published private(set) var outputDeviceName: String?
    @Published private(set) var queue: [NowPlayingQueueTrack] = []

    private let client = MediaRemoteClient()
    private var timer: AnyCancellable?
    private var inFlight = false
    private var emptyStreak = 0
    private var lastQueueRefresh = Date.distantPast
    private var lastVolumeWrite = Date.distantPast

    init() {
        volume = SystemOutputVolume.read()
        outputDeviceName = SystemOutputVolume.deviceName()
        refresh()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
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
                    queue = []
                }
            }
            if Date().timeIntervalSince(lastVolumeWrite) > 0.4 {
                let currentVolume = SystemOutputVolume.read()
                if abs(currentVolume - volume) > 0.01 { volume = currentVolume }
            }
            let device = SystemOutputVolume.deviceName()
            if device != outputDeviceName { outputDeviceName = device }
            refreshQueueIfNeeded()
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
        lastQueueRefresh = .distantPast
        refresh()
    }

    func previousTrack() {
        client.send(.previousTrack)
        lastQueueRefresh = .distantPast
        refresh()
    }

    func setVolume(_ value: Double) {
        let clamped = min(1, max(0, value))
        volume = clamped
        lastVolumeWrite = Date()
        SystemOutputVolume.write(clamped)
    }

    func openSourceApp() {
        let bundle = info.sourceBundleIdentifier
        guard !bundle.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func refreshQueueIfNeeded() {
        guard Date().timeIntervalSince(lastQueueRefresh) > 8 || queue.isEmpty else { return }
        lastQueueRefresh = Date()
        let fetched = MusicAppleScriptClient.fetchQueue().map {
            NowPlayingQueueTrack(title: $0.title, artist: $0.artist, duration: $0.duration)
        }
        if fetched != queue { queue = fetched }
    }
}
