import XCTest
@testable import DevNotch

final class NowPlayingTests: XCTestCase {
    func testParseNowPlayingDictionary() {
        let dict: NSDictionary = [
            "kMRMediaRemoteNowPlayingInfoTitle": "东风破",
            "kMRMediaRemoteNowPlayingInfoArtist": "周杰伦",
            "kMRMediaRemoteNowPlayingInfoAlbum": "叶惠美",
            "kMRMediaRemoteNowPlayingInfoDuration": 315.4,
            "kMRMediaRemoteNowPlayingInfoElapsedTime": 22.9,
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": 1,
            "kMRMediaRemoteNowPlayingInfoTimestamp": Date()
        ]
        let info = MediaRemoteClient.parse(dict: dict, isPlaying: true)
        XCTAssertTrue(info.hasTrack)
        XCTAssertEqual(info.title, "东风破")
        XCTAssertEqual(info.artist, "周杰伦")
        XCTAssertEqual(info.duration, 315.4, accuracy: 0.01)
        XCTAssertTrue(info.isPlaying)
        XCTAssertGreaterThan(info.progress, 0)
        XCTAssertLessThan(info.progress, 1)
    }

    func testEmptyDictionaryHasNoTrack() {
        let info = MediaRemoteClient.parse(dict: [:], isPlaying: false)
        XCTAssertFalse(info.hasTrack)
        XCTAssertEqual(info.progress, 0)
    }

    func testClockFormatting() {
        XCTAssertEqual(NowPlayingView.formatClock(0), "0:00")
        XCTAssertEqual(NowPlayingView.formatClock(65), "1:05")
        XCTAssertEqual(NowPlayingView.formatClock(315.4), "5:15")
    }

    func testCommandRawValuesMatchMediaRemote() {
        XCTAssertEqual(NowPlayingCommand.play.rawValue, 0)
        XCTAssertEqual(NowPlayingCommand.pause.rawValue, 1)
        XCTAssertEqual(NowPlayingCommand.togglePlayPause.rawValue, 2)
        XCTAssertEqual(NowPlayingCommand.nextTrack.rawValue, 4)
        XCTAssertEqual(NowPlayingCommand.previousTrack.rawValue, 5)
    }

    func testHelperJSONParsing() {
        let json = """
        {"title":"东风破","artist":"周杰伦","album":"叶惠美","duration":315.4,"elapsed":40,"playing":true,"rate":1}
        """
        let info = NowPlayingHelperClient.parse(Data(json.utf8))
        XCTAssertEqual(info?.title, "东风破")
        XCTAssertEqual(info?.artist, "周杰伦")
        XCTAssertEqual(info?.isPlaying, true)
    }

    func testElapsedUsesNowPlayingTimestamp() {
        let started = Date().addingTimeInterval(-40)
        let json = """
        {"title":"倒影","artist":"周杰伦","duration":234,"elapsed":0.25,"playing":true,"rate":1,"timestamp":\(started.timeIntervalSince1970)}
        """
        let info = NowPlayingHelperClient.parse(Data(json.utf8))
        XCTAssertNotNil(info)
        let elapsed = info!.currentElapsed()
        XCTAssertGreaterThan(elapsed, 35)
        XCTAssertLessThan(elapsed, 50)
    }
}
