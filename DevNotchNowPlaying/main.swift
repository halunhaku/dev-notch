import Foundation

func main() {
    let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    guard let handle = dlopen(path, RTLD_NOW) else {
        fputs("dlopen failed\n", stderr)
        exit(2)
    }

    typealias GetInfo = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
    typealias GetPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    typealias Send = @convention(c) (UInt32, AnyObject?) -> Bool

    let args = Array(CommandLine.arguments.dropFirst())
    if let command = args.first, command != "info" {
        guard let sendSym = dlsym(handle, "MRMediaRemoteSendCommand") else { exit(3) }
        let send = unsafeBitCast(sendSym, to: Send.self)
        let code: UInt32
        switch command {
        case "play": code = 0
        case "pause": code = 1
        case "toggle": code = 2
        case "next": code = 4
        case "previous": code = 5
        default:
            fputs("unknown command\n", stderr)
            exit(4)
        }
        _ = send(code, nil)
        return
    }

    guard let infoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
          let playSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
        exit(3)
    }
    let getInfo = unsafeBitCast(infoSym, to: GetInfo.self)
    let getPlaying = unsafeBitCast(playSym, to: GetPlaying.self)
    let queue = DispatchQueue(label: "nowplaying")
    let playingSem = DispatchSemaphore(value: 0)
    let infoSem = DispatchSemaphore(value: 0)
    var playing = false
    var dict: NSDictionary?

    getPlaying(queue) { value in
        playing = value
        playingSem.signal()
    }
    _ = playingSem.wait(timeout: .now() + 2)

    getInfo(queue) { info in
        dict = info
        infoSem.signal()
    }
    _ = infoSem.wait(timeout: .now() + 2)

    var payload: [String: Any] = ["playing": playing]
    if let dict {
        func stringValue(suffix: String) -> String? {
            for key in dict.allKeys {
                if String(describing: key).hasSuffix(suffix), let value = dict[key] as? String, !value.isEmpty {
                    return value
                }
            }
            return nil
        }
        func numberValue(suffix: String) -> Double? {
            for key in dict.allKeys {
                if String(describing: key).hasSuffix(suffix), let value = dict[key] as? NSNumber {
                    return value.doubleValue
                }
            }
            return nil
        }
        if let title = stringValue(suffix: "Title") { payload["title"] = title }
        if let artist = stringValue(suffix: "Artist") { payload["artist"] = artist }
        if let album = stringValue(suffix: "Album") { payload["album"] = album }
        if let duration = numberValue(suffix: "Duration") { payload["duration"] = duration }
        if let elapsed = numberValue(suffix: "ElapsedTime") { payload["elapsed"] = elapsed }
        if let rate = numberValue(suffix: "PlaybackRate") { payload["rate"] = rate }
        payload["keyCount"] = dict.count
    }

    guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []),
          let line = String(data: json, encoding: .utf8) else {
        exit(5)
    }
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

main()
