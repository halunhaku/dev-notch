import XCTest
@testable import DevNotch

final class AIProviderStatusTests: XCTestCase {
    func testStatusDescriptionsAndReadiness() {
        XCTAssertEqual(AIProviderStatus.checking.shortDescription, "Checking…")
        XCTAssertFalse(AIProviderStatus.checking.isReady)

        XCTAssertEqual(AIProviderStatus.notInstalled.shortDescription, "Not Installed")
        XCTAssertFalse(AIProviderStatus.notInstalled.isReady)

        XCTAssertEqual(AIProviderStatus.notAuthenticated.shortDescription, "Sign in required")
        XCTAssertFalse(AIProviderStatus.notAuthenticated.isReady)

        XCTAssertEqual(AIProviderStatus.ready.shortDescription, "Ready")
        XCTAssertTrue(AIProviderStatus.ready.isReady)

        XCTAssertEqual(AIProviderStatus.unavailable(reason: "Offline").shortDescription, "Unavailable")
        XCTAssertFalse(AIProviderStatus.unavailable(reason: "Offline").isReady)

        XCTAssertEqual(AIProviderStatus.error(message: "Crash").shortDescription, "Error")
        XCTAssertFalse(AIProviderStatus.error(message: "Crash").isReady)
    }

    func testProviderIDs() {
        XCTAssertEqual(AIProviderID.codex.displayName, "Codex")
        XCTAssertEqual(AIProviderID.claude.displayName, "Claude Code")
        XCTAssertEqual(AIProviderID.antigravity.displayName, "Google Antigravity")
        XCTAssertEqual(AIProviderID.openCodeGo.displayName, "OpenCode Go")
        XCTAssertEqual(AIProviderID.deepseek.displayName, "DeepSeek")
        XCTAssertEqual(AIProviderID.grok.displayName, "Grok")
    }
}
