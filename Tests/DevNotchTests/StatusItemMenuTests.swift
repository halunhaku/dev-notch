import XCTest
@testable import DevNotch

@MainActor
final class StatusItemMenuTests: XCTestCase {
    func testMenuStringFormattingFromSnapshots() {
        // Snapshot for Codex
        let codexSnapshot = AIProviderSnapshot(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            account: nil,
            metrics: [],
            compactMetric: AICompactMetric(label: "Codex", value: "84%", secondaryValue: "5h")
        )

        // Snapshot for DeepSeek
        let deepseekSnapshot = AIProviderSnapshot(
            id: .deepseek,
            displayName: "DeepSeek",
            status: .ready,
            account: nil,
            metrics: [],
            compactMetric: AICompactMetric(label: "DeepSeek", value: "¥0.73")
        )

        // Snapshot for unauthenticated Claude
        let claudeSnapshot = AIProviderSnapshot(
            id: .claude,
            displayName: "Claude Code",
            status: .notAuthenticated,
            account: nil,
            metrics: [],
            compactMetric: AICompactMetric(label: "Claude", value: "Sign in required", severity: .warning)
        )

        func formatItem(snapshot: AIProviderSnapshot) -> String {
            if snapshot.status == .ready {
                return "\(snapshot.displayName): \(snapshot.compactMetric.value)"
            } else {
                return "\(snapshot.displayName): \(snapshot.status.shortDescription)"
            }
        }

        XCTAssertEqual(formatItem(snapshot: codexSnapshot), "Codex: 84%")
        XCTAssertEqual(formatItem(snapshot: deepseekSnapshot), "DeepSeek: ¥0.73")
        XCTAssertEqual(formatItem(snapshot: claudeSnapshot), "Claude Code: Sign in required")
    }

    func testPreferencesToggleMenuBarItem() {
        let store = PreferencesStore(launchManager: MockLaunchAtLoginManager())

        XCTAssertTrue(store.showMenuBarItem)
        store.showMenuBarItem = false
        XCTAssertFalse(store.showMenuBarItem)
        store.showMenuBarItem = true
        XCTAssertTrue(store.showMenuBarItem)
    }
}
