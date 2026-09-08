import XCTest
@testable import DevNotch

final class AntigravityIntegrationTests: XCTestCase {
    private var tempHooksURL: URL!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempHooksURL = tempDir.appendingPathComponent("antigravity_hooks_\(UUID().uuidString).json")
    }

    override func tearDown() {
        if let url = tempHooksURL {
            try? FileManager.default.removeItem(at: url)
        }
        super.tearDown()
    }

    func testExistingNamedHooksPreservedDuringInstall() throws {
        // Existing hooks.json with user-defined hooks
        let initialJSON = """
        {
          "my-lint-checker": {
            "PostToolUse": [
              {
                "matcher": "run_command",
                "hooks": [
                  {
                    "type": "command",
                    "command": "./scripts/lint.sh"
                  }
                ]
              }
            ]
          }
        }
        """
        try initialJSON.data(using: .utf8)!.write(to: tempHooksURL)

        // Install Dev Notch integration
        try AntigravityIntegrationManager.install(
            bridgeExecutablePath: "/tmp/DevNotchActivityBridge",
            hooksURL: tempHooksURL
        )

        // Verify installed
        XCTAssertTrue(AntigravityIntegrationManager.isInstalled(hooksURL: tempHooksURL))

        let data = try Data(contentsOf: tempHooksURL)
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // 1. Existing hook preserved
        XCTAssertNotNil(root["my-lint-checker"])

        // 2. Dev Notch hook installed
        let devNotch = root["dev-notch-antigravity"] as! [String: Any]
        XCTAssertNotNil(devNotch["PreInvocation"])
        XCTAssertNotNil(devNotch["PreToolUse"])
        XCTAssertNotNil(devNotch["Stop"])

        // 3. Uninstall removes ONLY dev-notch-antigravity
        try AntigravityIntegrationManager.uninstall(hooksURL: tempHooksURL)
        XCTAssertFalse(AntigravityIntegrationManager.isInstalled(hooksURL: tempHooksURL))

        let uninstalledData = try Data(contentsOf: tempHooksURL)
        let uninstalledRoot = try JSONSerialization.jsonObject(with: uninstalledData) as! [String: Any]
        XCTAssertNotNil(uninstalledRoot["my-lint-checker"])
        XCTAssertNil(uninstalledRoot["dev-notch-antigravity"])
    }

    func testMalformedHooksJsonHandling() {
        let malformed = "{ malformed json".data(using: .utf8)!
        try? malformed.write(to: tempHooksURL)

        XCTAssertFalse(AntigravityIntegrationManager.isInstalled(hooksURL: tempHooksURL))
    }

    func testOwnStaleHookIsRepairedAndOtherNamedHookIsUntouched() throws {
        let initialJSON = """
        {
          "dev-notch-antigravity": {"enabled": true, "Stop": [{"type": "command", "command": "'/old/DevNotch.app/Contents/Helpers/DevNotchActivityBridge' antigravity Stop"}]},
          "third-party": {"Stop": [{"type": "command", "command": "/usr/bin/true"}]}
        }
        """
        try initialJSON.data(using: .utf8)!.write(to: tempHooksURL)
        let path = "/Applications/Dev Notch.app/Contents/Helpers/DevNotchActivityBridge"

        try AntigravityIntegrationManager.install(bridgeExecutablePath: path, hooksURL: tempHooksURL)

        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: tempHooksURL)) as! [String: Any]
        XCTAssertNotNil(root["third-party"])
        let own = root["dev-notch-antigravity"] as! [String: Any]
        let stop = own["Stop"] as! [[String: Any]]
        XCTAssertTrue((stop[0]["command"] as! String).contains(path))
        XCTAssertFalse((stop[0]["command"] as! String).contains("/old/"))
    }

    func testHelperPathWithSpacesIsShellQuoted() throws {
        let path = "/Applications/Dev Notch.app/Contents/Helpers/DevNotchActivityBridge"
        try AntigravityIntegrationManager.install(bridgeExecutablePath: path, hooksURL: tempHooksURL)
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: tempHooksURL)) as! [String: Any]
        let own = root["dev-notch-antigravity"] as! [String: Any]
        let stop = own["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop[0]["command"] as? String, "'\(path)' antigravity Stop")
    }
}
