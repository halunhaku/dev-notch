import Foundation

enum NowPlayingHelperClient {
    static func fetch() async -> NowPlayingInfo? {
        guard let data = try? await run() else { return nil }
        return parse(data)
    }

    static func send(_ command: NowPlayingCommand) {
        let argument: String
        switch command {
        case .play: argument = "play"
        case .pause: argument = "pause"
        case .togglePlayPause: argument = "toggle"
        case .nextTrack: argument = "next"
        case .previousTrack: argument = "previous"
        }
        Task {
            _ = try? await run(arguments: [argument])
        }
    }

    static func parse(_ data: Data) -> NowPlayingInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let title = object["title"] as? String ?? ""
        let artist = object["artist"] as? String ?? ""
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        var artwork: Data?
        if let b64 = object["artwork"] as? String {
            artwork = Data(base64Encoded: b64)
        }
        let timestamp: Date
        if let raw = object["timestamp"] as? Double {
            timestamp = Date(timeIntervalSince1970: raw)
        } else if let raw = object["timestamp"] as? NSNumber {
            timestamp = Date(timeIntervalSince1970: raw.doubleValue)
        } else {
            timestamp = Date()
        }
        return NowPlayingInfo(
            title: title,
            artist: artist,
            album: object["album"] as? String ?? "",
            duration: (object["duration"] as? NSNumber)?.doubleValue ?? (object["duration"] as? Double) ?? 0,
            elapsed: (object["elapsed"] as? NSNumber)?.doubleValue ?? (object["elapsed"] as? Double) ?? 0,
            isPlaying: object["playing"] as? Bool ?? false,
            playbackRate: (object["rate"] as? NSNumber)?.doubleValue ?? (object["rate"] as? Double) ?? 0,
            timestamp: timestamp,
            artworkData: artwork
        )
    }

    private static func run(arguments: [String] = []) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    var env = ProcessInfo.processInfo.environment
                    env["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"
                    process.environment = env
                    if let swift = swiftExecutable(), let script = try? materializeProbeScript() {
                        process.executableURL = URL(fileURLWithPath: swift)
                        process.arguments = [script.path] + arguments
                    } else {
                        let path = try BundledHelperLocator.executablePath(for: .nowPlaying)
                        process.executableURL = URL(fileURLWithPath: path)
                        process.arguments = arguments
                    }
                    let stdout = Pipe()
                    process.standardOutput = stdout
                    process.standardError = FileHandle.nullDevice
                    try process.run()
                    let data = stdout.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: POSIXError(.EIO))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func swiftExecutable() -> String? {
        let candidates = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift",
            "/usr/bin/swift"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Compiled Mach-O helpers get empty MediaRemote; Apple-signed `swift` does not.
    private static func materializeProbeScript() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DevNotchNowPlayingProbe.swift")
        try probeSource.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static let probeSource = #"""
    import Foundation
    let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    guard let handle = dlopen(path, RTLD_NOW) else {
        FileHandle.standardOutput.write(Data("{\"playing\":false}\n".utf8)); exit(0)
    }
    typealias GetInfo = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
    typealias GetPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    typealias Send = @convention(c) (UInt32, AnyObject?) -> Bool
    let args = Array(CommandLine.arguments.dropFirst())
    if let command = args.first, ["play","pause","toggle","next","previous"].contains(command) {
        guard let sendSym = dlsym(handle, "MRMediaRemoteSendCommand") else { exit(3) }
        let send = unsafeBitCast(sendSym, to: Send.self)
        let code: UInt32 = command == "play" ? 0 : command == "pause" ? 1 : command == "toggle" ? 2 : command == "next" ? 4 : 5
        _ = send(code, nil); exit(0)
    }
    guard let infoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
          let playSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
        FileHandle.standardOutput.write(Data("{\"playing\":false}\n".utf8)); exit(0)
    }
    let getInfo = unsafeBitCast(infoSym, to: GetInfo.self)
    let getPlaying = unsafeBitCast(playSym, to: GetPlaying.self)
    let queue = DispatchQueue(label: "nowplaying")
    let playingSem = DispatchSemaphore(value: 0)
    let infoSem = DispatchSemaphore(value: 0)
    var playing = false
    var dict: NSDictionary?
    getPlaying(queue) { value in playing = value; playingSem.signal() }
    _ = playingSem.wait(timeout: .now() + 2)
    getInfo(queue) { info in dict = info; infoSem.signal() }
    _ = infoSem.wait(timeout: .now() + 2)
    var payload: [String: Any] = ["playing": playing]
    if let dict {
        if let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String { payload["title"] = title }
        if let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String { payload["artist"] = artist }
        if let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String { payload["album"] = album }
        if let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber { payload["duration"] = duration.doubleValue }
        if let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber { payload["elapsed"] = elapsed.doubleValue }
        if let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber { payload["rate"] = rate.doubleValue }
        if let ts = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
            payload["timestamp"] = ts.timeIntervalSince1970
        }
        if let data = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, data.count < 250_000 {
            payload["artwork"] = data.base64EncodedString()
        }
    }
    if let json = try? JSONSerialization.data(withJSONObject: payload),
       let line = String(data: json, encoding: .utf8) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
    """#
}
