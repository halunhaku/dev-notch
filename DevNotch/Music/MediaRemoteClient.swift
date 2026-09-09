import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "MediaRemote")

private final class ContinuationGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) {
        let pending = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: value)
    }
}

/// Reads system Now Playing via private MediaRemote. GitHub-distributed; not App Store.
final class MediaRemoteClient: @unchecked Sendable {
    private let handle: UnsafeMutableRawPointer?
    private let getInfo: (@convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void)?
    private let getPlaying: (@convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void)?
    private let sendCommand: (@convention(c) (UInt32, AnyObject?) -> Bool)?
    private let getPID: (@convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void)?
    private let queue = DispatchQueue(label: "com.halunhaku.DevNotch.mediaremote")

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        handle = dlopen(path, RTLD_NOW)
        if handle == nil {
            logger.error("MediaRemote dlopen failed")
        }

        typealias GetInfo = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
        typealias GetPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
        typealias Send = @convention(c) (UInt32, AnyObject?) -> Bool
        typealias Register = @convention(c) (DispatchQueue) -> Void

        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(symbol, to: GetInfo.self)
        } else {
            getInfo = nil
        }
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getPlaying = unsafeBitCast(symbol, to: GetPlaying.self)
        } else {
            getPlaying = nil
        }
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(symbol, to: Send.self)
        } else {
            sendCommand = nil
        }
        typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            getPID = unsafeBitCast(symbol, to: GetPID.self)
        } else {
            getPID = nil
        }
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let register = unsafeBitCast(symbol, to: Register.self)
            register(queue)
        }
    }

    func fetch() async -> NowPlayingInfo {
        var info: NowPlayingInfo
        if let helper = await NowPlayingHelperClient.fetch(), helper.hasTrack {
            info = helper
        } else {
            let remote = await fetchMediaRemote()
            if remote.hasTrack {
                info = remote
            } else {
                info = await Task.detached(priority: .utility) {
                    MusicAppleScriptClient.fetch() ?? .empty
                }.value
            }
        }
        guard info.hasTrack else { return info }
        let source = await fetchSourceApp()
        info.sourceAppName = source.name
        info.sourceBundleIdentifier = source.bundle
        return info
    }

    func send(_ command: NowPlayingCommand) {
        NowPlayingHelperClient.send(command)
        if let sendCommand {
            _ = sendCommand(command.rawValue, nil)
        }
        if MusicAppleScriptClient.isMusicRunning() {
            MusicAppleScriptClient.send(command)
        }
    }

    private func fetchSourceApp() async -> (name: String, bundle: String) {
        guard let getPID else { return ("", "") }
        let pid: Int32 = await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)
            queue.asyncAfter(deadline: .now() + 0.6) {
                gate.resume(returning: 0)
            }
            getPID(queue) {
                gate.resume(returning: $0)
            }
        }
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else {
            return ("", "")
        }
        return (app.localizedName ?? "", app.bundleIdentifier ?? "")
    }

    private func fetchMediaRemote() async -> NowPlayingInfo {
        let playing = await fetchPlaying()
        return await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)
            guard let getInfo else {
                gate.resume(returning: .empty)
                return
            }
            queue.asyncAfter(deadline: .now() + 1.0) {
                gate.resume(returning: .empty)
            }
            getInfo(queue) { dict in
                gate.resume(returning: Self.parse(dict: dict, isPlaying: playing))
            }
        }
    }

    private func fetchPlaying() async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)
            guard let getPlaying else {
                gate.resume(returning: false)
                return
            }
            queue.asyncAfter(deadline: .now() + 0.6) {
                gate.resume(returning: false)
            }
            getPlaying(queue) { playing in
                gate.resume(returning: playing)
            }
        }
    }

    static func parse(dict: NSDictionary?, isPlaying: Bool) -> NowPlayingInfo {
        guard let dict, dict.count > 0 else { return .empty }
        let title = string(dict, suffix: "Title")
        let artist = string(dict, suffix: "Artist")
        let album = string(dict, suffix: "Album")
        guard !title.isEmpty || !artist.isEmpty else { return .empty }

        return NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            duration: number(dict, suffix: "Duration"),
            elapsed: number(dict, suffix: "ElapsedTime"),
            isPlaying: isPlaying,
            playbackRate: number(dict, suffix: "PlaybackRate"),
            timestamp: (value(dict, suffix: "Timestamp") as? Date) ?? Date(),
            artworkData: value(dict, suffix: "ArtworkData") as? Data
        )
    }

    private static func value(_ dict: NSDictionary, suffix: String) -> Any? {
        let full = "kMRMediaRemoteNowPlayingInfo\(suffix)"
        if let match = dict[full] { return match }
        for key in dict.allKeys {
            let name = String(describing: key)
            if name == full || name.hasSuffix(suffix) {
                return dict[key]
            }
        }
        return nil
    }

    private static func string(_ dict: NSDictionary, suffix: String) -> String {
        (value(dict, suffix: suffix) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func number(_ dict: NSDictionary, suffix: String) -> Double {
        (value(dict, suffix: suffix) as? NSNumber)?.doubleValue ?? 0
    }
}
