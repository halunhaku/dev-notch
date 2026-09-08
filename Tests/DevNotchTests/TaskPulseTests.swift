import XCTest
import SwiftUI
@testable import DevNotch

final class TaskPulseTests: XCTestCase {
    func testTaskPulseStateMapping() {
        // 1. Working state produces active pulse
        let workingPulse = TaskPulseView(state: .working, isTransientDone: false)
        XCTAssertEqual(workingPulse.state, .working)
        XCTAssertFalse(workingPulse.isTransientDone)

        // 2. Completed state produces transient success flash
        let completedPulse = TaskPulseView(state: .idle, isTransientDone: true)
        XCTAssertTrue(completedPulse.isTransientDone)

        // 3. Waiting for approval produces steady indicator
        let approvalPulse = TaskPulseView(state: .waitingForApproval, isTransientDone: false)
        XCTAssertEqual(approvalPulse.state, .waitingForApproval)

        // 4. Idle state is empty
        let idlePulse = TaskPulseView(state: .idle, isTransientDone: false)
        XCTAssertEqual(idlePulse.state, .idle)
    }

    @MainActor
    func testSimultaneousWorkingProvidersIsolation() async {
        let registry = AIProviderRegistry()
        let claude = MockTestProvider(
            id: .claude,
            displayName: "Claude Code",
            status: .ready,
            compactMetric: AICompactMetric(label: "Claude", value: "Working", severity: .normal)
        )
        let antigravity = MockTestProvider(
            id: .antigravity,
            displayName: "Google Antigravity",
            status: .ready,
            compactMetric: AICompactMetric(label: "Antigravity", value: "Working", severity: .normal)
        )

        registry.register(claude)
        registry.register(antigravity)

        let manager = AIProviderManager(registry: registry)
        // User primary is Claude
        manager.setPrimaryProvider(.claude)
        manager.start()

        try? await Task.sleep(nanoseconds: 50_000_000)

        // 1. Both providers are working concurrently in their snapshots
        XCTAssertEqual(manager.snapshots[.claude]?.compactMetric.value, "Working")
        XCTAssertEqual(manager.snapshots[.antigravity]?.compactMetric.value, "Working")

        // 2. Compact notch strictly reflects Primary Provider (Claude)
        XCTAssertEqual(manager.activePrimaryID, .claude)
        XCTAssertEqual(manager.primaryCompactMetric.label, "Claude")
        XCTAssertEqual(manager.primaryCompactMetric.value, "Working")

        // 3. User switches primary to Antigravity -> Compact seamlessly updates to Antigravity
        manager.setPrimaryProvider(.antigravity)
        XCTAssertEqual(manager.activePrimaryID, .antigravity)
        XCTAssertEqual(manager.primaryCompactMetric.label, "Antigravity")
        XCTAssertEqual(manager.primaryCompactMetric.value, "Working")
    }
}
