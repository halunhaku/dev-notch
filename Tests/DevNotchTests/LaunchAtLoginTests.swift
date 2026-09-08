import XCTest
@testable import DevNotch

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testLaunchAtLoginEnableAndDisable() throws {
        let mock = MockLaunchAtLoginManager()
        XCTAssertFalse(mock.isEnabled)

        try mock.setEnabled(true)
        XCTAssertTrue(mock.isEnabled)

        try mock.setEnabled(false)
        XCTAssertFalse(mock.isEnabled)
    }

    func testLaunchAtLoginFailureHandling() {
        let mock = MockLaunchAtLoginManager()
        mock.shouldThrow = true

        XCTAssertThrowsError(try mock.setEnabled(true)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Permission denied"))
        }
    }

    func testLaunchAtLoginRequiresStableApplicationLocation() {
        let manager = DefaultLaunchAtLoginManager(
            bundleURL: URL(fileURLWithPath: "/Volumes/DevNotch/DevNotch.app")
        )
        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            XCTAssertEqual(error as? ReleaseEnvironmentError, .unstableInstallLocation)
        }
    }
}
