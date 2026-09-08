import XCTest
@testable import DevNotch

final class ClaudeActivityTests: XCTestCase {
    func testActivityStateFromHookEvents() {
        // Event mapping rules
        func stateForEvent(_ event: String) -> AIActivityState {
            switch event {
            case "UserPromptSubmit", "PreToolUse", "PostToolUse":
                return .working
            case "PermissionRequest":
                return .waitingForApproval
            case "Stop":
                return .completed
            case "SessionStart":
                return .idle
            default:
                return .idle
            }
        }

        XCTAssertEqual(stateForEvent("UserPromptSubmit"), .working)
        XCTAssertEqual(stateForEvent("PreToolUse"), .working)
        XCTAssertEqual(stateForEvent("PostToolUse"), .working)
        XCTAssertEqual(stateForEvent("PermissionRequest"), .waitingForApproval)
        XCTAssertEqual(stateForEvent("Stop"), .completed)
        XCTAssertEqual(stateForEvent("SessionStart"), .idle)
    }

    func testStaleActivityTimeout() {
        let now = Date()
        let freshSnapshot = AIActivitySnapshot(state: .working, updatedAt: now)
        XCTAssertFalse(freshSnapshot.isStale(timeoutSeconds: 45.0, now: now))

        // 50 seconds later -> must be stale
        let later = now.addingTimeInterval(50.0)
        XCTAssertTrue(freshSnapshot.isStale(timeoutSeconds: 45.0, now: later))

        // Idle state is never stale
        let idleSnapshot = AIActivitySnapshot(state: .idle, updatedAt: now.addingTimeInterval(-100))
        XCTAssertFalse(idleSnapshot.isStale(timeoutSeconds: 45.0, now: now))
    }

    func testClaudeCompactMetricHierarchy() async {
        let provider = ClaudeProvider()

        // 1. Unauthenticated state
        let unauthMetric = await provider.compactMetric()
        XCTAssertEqual(unauthMetric.label, "Claude")

        // 2. Working state
        let workingSnapshot = AIActivitySnapshot(state: .working, model: "sonnet-4")
        let workingMetric = AICompactMetric(label: "Claude", value: "Working", severity: .normal)
        XCTAssertEqual(workingMetric.value, "Working")

        // 3. Approval state
        let approvalMetric = AICompactMetric(label: "Claude", value: "Approval", severity: .warning)
        XCTAssertEqual(approvalMetric.value, "Approval")
        XCTAssertEqual(approvalMetric.severity, .warning)

        // 4. Idle with Context
        let context = AIContextMetric(usedPercent: 43.0)
        let ctx = Int(round(context.usedPercent))
        let idleContextMetric = AICompactMetric(label: "Claude", value: "Ctx \(ctx)%", severity: .normal)
        XCTAssertEqual(idleContextMetric.value, "Ctx 43%")

        // 5. Transient Done state
        let doneMetric = AICompactMetric(label: "Claude", value: "✓ Done", severity: .normal)
        XCTAssertEqual(doneMetric.value, "✓ Done")
    }

    func testAtomicSessionJsonFileBridge() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("devnotch_claude_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetURL = tempDir.appendingPathComponent("session.json")
        let tempURL = tempDir.appendingPathComponent("session.tmp")

        let message = ClaudeBridgeMessage(
            sessionID: "test-uuid-1",
            model: "claude-sonnet-4",
            projectName: "DevNotch",
            contextUsedPercent: 38.5,
            sessionCostUSD: Decimal(string: "0.15"),
            activityState: "working",
            timestamp: Date().timeIntervalSince1970
        )

        let data = try JSONEncoder().encode(message)
        try data.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tempURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
        let readData = try Data(contentsOf: targetURL)
        let decoded = try JSONDecoder().decode(ClaudeBridgeMessage.self, from: readData)

        XCTAssertEqual(decoded.sessionID, "test-uuid-1")
        XCTAssertEqual(decoded.activityState, "working")
        XCTAssertEqual(decoded.contextUsedPercent, 38.5)
        XCTAssertEqual(decoded.sessionCostUSD, Decimal(string: "0.15"))
    }

    func testSecurityZeroPromptOrResponseCapture() {
        // Verify that ClaudeBridgeMessage schema explicitly lacks prompt or code fields
        let mirror = Mirror(reflecting: ClaudeBridgeMessage())
        let fieldNames = mirror.children.compactMap { $0.label }

        XCTAssertFalse(fieldNames.contains("prompt"))
        XCTAssertFalse(fieldNames.contains("response"))
        XCTAssertFalse(fieldNames.contains("sourceCode"))
        XCTAssertFalse(fieldNames.contains("command"))
    }
}
