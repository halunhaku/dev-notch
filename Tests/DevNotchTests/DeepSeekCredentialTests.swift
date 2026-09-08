import XCTest
@testable import DevNotch

final class DeepSeekCredentialTests: XCTestCase {
    func testCredentialDiscoveredFromOpenCodeFixture() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempAuthPath = tempDir.appendingPathComponent("opencode_auth_\(UUID().uuidString).json")

        let json = """
        {
          "deepseek": {
            "type": "api",
            "key": "sk-test1234567890abcdef"
          }
        }
        """
        try json.data(using: .utf8)!.write(to: tempAuthPath)
        defer { try? FileManager.default.removeItem(at: tempAuthPath) }

        let credential = DeepSeekCredentialLocator.locate(customAuthPath: tempAuthPath.path)
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential?.source, .openCode)
        XCTAssertEqual(credential?.apiKey, "sk-test1234567890abcdef")
    }

    func testMissingCredentialReturnsNil() {
        let nonexistentPath = "/tmp/nonexistent_auth_\(UUID().uuidString).json"
        let credential = DeepSeekCredentialLocator.locate(customAuthPath: nonexistentPath)
        // If environment has no DEEPSEEK_API_KEY, should be nil
        if ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] == nil {
            XCTAssertNil(credential)
        }
    }
}
