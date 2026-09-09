import Foundation

let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
guard let handle = dlopen(path, RTLD_NOW) else {
    FileHandle.standardOutput.write(Data("{\"playing\":false}\n".utf8))
    exit(0)
}

typealias GetInfo = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
typealias GetPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias Send = @convention(c) (UInt32, AnyObject?) -> Bool

let args = Array(CommandLine.arguments.dropFirst())
if let command = args.first, ["play", "pause", "toggle", "next", "previous"].contains(command) {
    guard let sendSym = dlsym(handle, "MRMediaRemoteSendCommand") else { exit(3) }
    let send = unsafeBitCast(sendSym, to: Send.self)
    let code: UInt32
    switch command {
    case "play": code = 0
    case "pause": code = 1
    case "toggle": code = 2
    case "next": code = 4
    default: code = 5
    }
    _ = send(code, nil)
    exit(0)
}

guard let infoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
      let playSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
    FileHandle.standardOutput.write(Data("{\"playing\":false}\n".utf8))
    exit(0)
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
    if let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String { payload["title"] = title }
    if let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String { payload["artist"] = artist }
    if let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String { payload["album"] = album }
    if let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber { payload["duration"] = duration.doubleValue }
    if let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber { payload["elapsed"] = elapsed.doubleValue }
    if let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber { payload["rate"] = rate.doubleValue }
    if let data = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, data.count < 250_000 {
        payload["artwork"] = data.base64EncodedString()
    }
}
if let json = try? JSONSerialization.data(withJSONObject: payload),
   let line = String(data: json, encoding: .utf8) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}
