import XCTest
@testable import DevNotch

final class MockAntigravityAppLocator: AntigravityAppLocating {
    let isInstalled: Bool
    let version: String?

    init(isInstalled: Bool, version: String? = nil) {
        self.isInstalled = isInstalled
        self.version = version
    }

    func isAppInstalled() -> Bool {
        return isInstalled
    }

    func appVersion() -> String? {
        return version
    }
}

final class AntigravityDiscoveryTests: XCTestCase {
    func testAgyExecutableDiscovery() {
        let path = AntigravityExecutableLocator.locate()
        XCTAssertNotNil(path)
        if let p = path {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: p))
            let version = AntigravityExecutableLocator.queryVersion(executablePath: p)
            XCTAssertNotNil(version)
            XCTAssertFalse(version!.isEmpty)
        }
    }

    func testInstallStates() {
        // 1. Both installed
        let bothState = AntigravityInstallState.both(cliVersion: "1.1.27", appVersion: "2.0.0")
        XCTAssertTrue(bothState.isInstalled)
        XCTAssertTrue(bothState.isDesktopInstalled)
        XCTAssertEqual(bothState.cliVersion, "1.1.27")

        // 2. CLI only
        let cliOnlyState = AntigravityInstallState.cliOnly(cliVersion: "1.1.27")
        XCTAssertTrue(cliOnlyState.isInstalled)
        XCTAssertFalse(cliOnlyState.isDesktopInstalled)
        XCTAssertEqual(cliOnlyState.cliVersion, "1.1.27")

        // 3. Desktop only
        let desktopOnlyState = AntigravityInstallState.desktopOnly(appVersion: "2.0.0")
        XCTAssertTrue(desktopOnlyState.isInstalled)
        XCTAssertTrue(desktopOnlyState.isDesktopInstalled)
        XCTAssertNil(desktopOnlyState.cliVersion)

        // 4. Neither installed
        let noneState = AntigravityInstallState.notInstalled
        XCTAssertFalse(noneState.isInstalled)
        XCTAssertFalse(noneState.isDesktopInstalled)
        XCTAssertNil(noneState.cliVersion)
    }

    func testAuthInspectorWithFixture() throws {
        let tempGemini = FileManager.default.temporaryDirectory.appendingPathComponent("gemini_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempGemini, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempGemini) }

        let accountsJSON = """
        {
          "active": "testuser@gmail.com"
        }
        """
        try accountsJSON.data(using: .utf8)!.write(to: tempGemini.appendingPathComponent("google_accounts.json"))

        let settingsJSON = """
        {
          "security": {
            "auth": {
              "selectedType": "oauth-personal"
            }
          }
        }
        """
        try settingsJSON.data(using: .utf8)!.write(to: tempGemini.appendingPathComponent("settings.json"))

        let cliDir = tempGemini.appendingPathComponent("antigravity-cli")
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)
        let cliSettingsJSON = """
        {
          "model": "Gemini 3.8 Flash (High)"
        }
        """
        try cliSettingsJSON.data(using: .utf8)!.write(to: cliDir.appendingPathComponent("settings.json"))

        let auth = AntigravityAuthInspector.inspect(geminiDir: tempGemini)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.email, "testuser@gmail.com")
        XCTAssertEqual(auth.authType, "oauth-personal")
        XCTAssertEqual(auth.modelName, "Gemini 3.8 Flash (High)")
    }
}
