import XCTest
@testable import DevNotch

/// Mock provider for deterministic multi-provider testing without live network or CLI dependencies.
final class MockTestProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID
    let displayName: String

    var mockStatus: AIProviderStatus
    var mockAccount: AIAccount?
    var mockUsage: AIUsage?
    var shouldThrowOnRefresh: Bool = false
    var refreshDelayNanoseconds: UInt64 = 0

    init(
        id: AIProviderID,
        displayName: String,
        status: AIProviderStatus = .ready,
        account: AIAccount? = nil,
        usage: AIUsage? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.mockStatus = status
        self.mockAccount = account
        self.mockUsage = usage
    }

    func currentStatus() async -> AIProviderStatus {
        return mockStatus
    }

    func start() async {}
    func stop() async {}

    func fetchAccount() async throws -> AIAccount? {
        if shouldThrowOnRefresh { throw URLError(.timedOut) }
        return mockAccount
    }

    func fetchUsage() async throws -> AIUsage? {
        if refreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        if shouldThrowOnRefresh { throw URLError(.timedOut) }
        return mockUsage
    }
}

@MainActor
final class AIProviderManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "devnotch_preferred_primary_id")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "devnotch_preferred_primary_id")
        super.tearDown()
    }

    func testBothProvidersReady() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            usage: AIUsage(windows: [AIUsageWindow(id: "5h", label: "5 Hour", durationMinutes: 300, usedPercent: 16)])
        )
        let openCode = MockTestProvider(
            id: .openCodeGo,
            displayName: "OpenCode Go",
            status: .ready,
            usage: AIUsage(windows: [AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 33)])
        )

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        manager.start()

        // Wait for async initialization
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.snapshots[.codex]?.status, .ready)
        XCTAssertEqual(manager.snapshots[.openCodeGo]?.status, .ready)
        XCTAssertEqual(manager.activePrimaryID, .codex)
        XCTAssertEqual(manager.primaryRemainingInt, 84)
    }

    func testCodexReadyAndOpenCodeError() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(id: .codex, displayName: "Codex", status: .ready)
        let openCode = MockTestProvider(id: .openCodeGo, displayName: "OpenCode Go", status: .error(message: "Auth failed"))

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        manager.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.snapshots[.codex]?.status, .ready)
        XCTAssertEqual(manager.snapshots[.openCodeGo]?.status, .error(message: "Auth failed"))
        XCTAssertEqual(manager.activePrimaryID, .codex)
    }

    func testCodexErrorAndOpenCodeReadyWithRuntimeFallback() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(id: .codex, displayName: "Codex", status: .unavailable(reason: "CLI missing"))
        let openCode = MockTestProvider(
            id: .openCodeGo,
            displayName: "OpenCode Go",
            status: .ready,
            usage: AIUsage(windows: [AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 40)])
        )

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        manager.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Preferred is still .codex
        XCTAssertEqual(manager.preferredPrimaryID, .codex)
        // Active runtime fallback is .openCodeGo because it is ready
        XCTAssertEqual(manager.activePrimaryID, .openCodeGo)
        XCTAssertEqual(manager.primaryRemainingInt, 60)
        XCTAssertEqual(manager.primaryDisplayName, "OpenCode Go")

        // Preferred setting was NOT overwritten
        XCTAssertEqual(manager.preferredPrimaryID, .codex)
    }

    func testBothProvidersError() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(id: .codex, displayName: "Codex", status: .error(message: "E1"))
        let openCode = MockTestProvider(id: .openCodeGo, displayName: "OpenCode Go", status: .error(message: "E2"))

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        manager.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.activePrimaryID, .codex)
        XCTAssertEqual(manager.primaryStatus, .error(message: "E1"))
    }

    func testPrimaryProviderSelectionAndPersistence() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(id: .codex, displayName: "Codex", status: .ready)
        let openCode = MockTestProvider(id: .openCodeGo, displayName: "OpenCode Go", status: .ready)

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        XCTAssertEqual(manager.preferredPrimaryID, .codex)

        // Switch preferred primary to OpenCode Go
        manager.setPrimaryProvider(.openCodeGo)
        XCTAssertEqual(manager.preferredPrimaryID, .openCodeGo)
        XCTAssertEqual(manager.activePrimaryID, .openCodeGo)

        // Verify persisted in UserDefaults
        let saved = UserDefaults.standard.string(forKey: "devnotch_preferred_primary_id")
        XCTAssertEqual(saved, "opencode_go")

        // Verify a new manager instance initializes with the saved preference
        let newManager = AIProviderManager(registry: registry)
        XCTAssertEqual(newManager.preferredPrimaryID, .openCodeGo)
    }

    func testProviderRefreshErrorAndTimeoutIsolation() async {
        let registry = AIProviderRegistry()
        // Provider 1 fails with timeout
        let failingProvider = MockTestProvider(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            usage: AIUsage(windows: [AIUsageWindow(id: "5h", label: "5 Hour", durationMinutes: 300, usedPercent: 10)])
        )
        failingProvider.shouldThrowOnRefresh = true

        // Provider 2 succeeds
        let workingProvider = MockTestProvider(
            id: .openCodeGo,
            displayName: "OpenCode Go",
            status: .ready,
            usage: AIUsage(windows: [AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 25)])
        )

        registry.register(failingProvider)
        registry.register(workingProvider)

        let manager = AIProviderManager(registry: registry)
        manager.refreshAll()

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Working provider must succeed and retain snapshot
        XCTAssertEqual(manager.snapshots[.openCodeGo]?.status, .ready)
        XCTAssertEqual(manager.snapshots[.openCodeGo]?.usage?.primaryRemainingInt, 75)
    }
}
