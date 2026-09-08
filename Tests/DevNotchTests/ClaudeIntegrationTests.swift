import XCTest
@testable import DevNotch

final class ClaudeIntegrationTests: XCTestCase {
    private var tempSettingsURL: URL!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempSettingsURL = tempDir.appendingPathComponent("claude_settings_\(UUID().uuidString).json")
    }

    override func tearDown() {
        if let url = tempSettingsURL {
            try? FileManager.default.removeItem(at: url)
        }
        super.tearDown()
    }

    func testExistingHooksPreservedDuringInstall() throws {
        // Setup existing settings with third-party hook (e.g. _otty_grok)
        let initialJSON = """
        {
          "customUserSetting": "keep_this_safe",
          "hooks": {
            "UserPromptSubmit": [
              {
                "_otty_grok": true,
                "hooks": [
                  {
                    "type": "command",
                    "command": "otty-hook processing"
                  }
                ]
              }
            ]
          }
        }
        """
        try initialJSON.data(using: .utf8)!.write(to: tempSettingsURL)

        // Install Dev Notch integration
        try ClaudeIntegrationManager.install(
            bridgeExecutablePath: "/tmp/DevNotchClaudeBridge",
            settingsURL: tempSettingsURL
        )

        // Read back
        let data = try Data(contentsOf: tempSettingsURL)
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // 1. User custom setting preserved
        XCTAssertEqual(root["customUserSetting"] as? String, "keep_this_safe")

        // 2. Existing _otty_grok hook preserved
        let hooks = root["hooks"] as! [String: Any]
        let userPromptSubmitList = hooks["UserPromptSubmit"] as! [[String: Any]]
        XCTAssertEqual(userPromptSubmitList.count, 2)

        let ottyHook = userPromptSubmitList.first(where: { ($0["_otty_grok"] as? Bool) == true })
        XCTAssertNotNil(ottyHook)

        // 3. Dev Notch hook installed
        let devNotchHook = userPromptSubmitList.first(where: { ($0["_dev_notch"] as? Bool) == true })
        XCTAssertNotNil(devNotchHook)

        // 4. Uninstall only removes Dev Notch hook
        try ClaudeIntegrationManager.uninstall(settingsURL: tempSettingsURL)

        let uninstalledData = try Data(contentsOf: tempSettingsURL)
        let uninstalledRoot = try JSONSerialization.jsonObject(with: uninstalledData) as! [String: Any]
        let uninstalledHooks = uninstalledRoot["hooks"] as! [String: Any]
        let uninstalledList = uninstalledHooks["UserPromptSubmit"] as! [[String: Any]]

        XCTAssertEqual(uninstalledList.count, 1)
        XCTAssertEqual(uninstalledList[0]["_otty_grok"] as? Bool, true)
        XCTAssertEqual(uninstalledRoot["customUserSetting"] as? String, "keep_this_safe")
    }

    func testExistingCustomStatusLinePreserved() throws {
        let initialJSON = """
        {
          "statusLine": {
            "type": "command",
            "command": "/usr/local/bin/my-custom-statusline.sh"
          }
        }
        """
        try initialJSON.data(using: .utf8)!.write(to: tempSettingsURL)

        try ClaudeIntegrationManager.install(
            bridgeExecutablePath: "/tmp/DevNotchClaudeBridge",
            settingsURL: tempSettingsURL
        )

        let data = try Data(contentsOf: tempSettingsURL)
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let statusLine = root["statusLine"] as! [String: Any]

        // Custom status line must NOT be overwritten!
        XCTAssertEqual(statusLine["command"] as? String, "/usr/local/bin/my-custom-statusline.sh")
    }

    func testMalformedClaudeSettingsHandledGracefully() {
        let malformed = "{ malformed json content".data(using: .utf8)!
        try? malformed.write(to: tempSettingsURL)

        // Must not crash when checking or updating
        XCTAssertFalse(ClaudeIntegrationManager.isInstalled(settingsURL: tempSettingsURL))
    }
}
