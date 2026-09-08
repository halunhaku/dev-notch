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
}
