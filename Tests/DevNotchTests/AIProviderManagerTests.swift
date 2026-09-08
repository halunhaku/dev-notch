import XCTest
@testable import DevNotch

/// Mock provider for deterministic multi-provider testing without live network or CLI dependencies.
final class MockTestProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID
    let displayName: String
    let refreshPolicy: AIProviderRefreshPolicy

    var mockStatus: AIProviderStatus
    var mockAccount: AIAccount?
    var mockMetrics: [AIProviderMetric] = []
    var mockCompactMetric: AICompactMetric
    var shouldThrowOnRefresh: Bool = false
    var refreshDelayNanoseconds: UInt64 = 0

    init(
        id: AIProviderID,
        displayName: String,
        status: AIProviderStatus = .ready,
        account: AIAccount? = nil,
        metrics: [AIProviderMetric] = [],
        compactMetric: AICompactMetric? = nil,
        refreshPolicy: AIProviderRefreshPolicy = .interval(60)
    ) {
        self.id = id
        self.displayName = displayName
        self.mockStatus = status
        self.mockAccount = account
        self.mockMetrics = metrics
        self.refreshPolicy = refreshPolicy
        self.mockCompactMetric = compactMetric ?? AICompactMetric(
            label: displayName,
            value: status == .ready ? "Ready" : status.shortDescription,
            severity: status == .ready ? .normal : .inactive
        )
    }

    func currentStatus() async -> AIProviderStatus {
        return mockStatus
    }

    func start() async {}
    func stop() async {}
    func refresh() async {}

    func fetchAccount() async throws -> AIAccount? {
        if shouldThrowOnRefresh { throw URLError(.timedOut) }
        return mockAccount
    }

    func fetchMetrics() async -> [AIProviderMetric] {
        if refreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        return mockMetrics
    }

    func compactMetric() async -> AICompactMetric {
        return mockCompactMetric
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
        let codexWindow = AIUsageWindow(id: "5h", label: "5 Hour", durationMinutes: 300, usedPercent: 16)
        let codex = MockTestProvider(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            metrics: [.usageWindow(codexWindow)],
            compactMetric: AICompactMetric(label: "Codex", value: "84%", secondaryValue: "5h", severity: .normal)
        )

        let openCodeWindow = AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 33)
        let openCode = MockTestProvider(
            id: .openCodeGo,
            displayName: "OpenCode Go",
            status: .ready,
            metrics: [.usageWindow(openCodeWindow)],
            compactMetric: AICompactMetric(label: "OpenCode Go", value: "67%", secondaryValue: "5h", severity: .normal)
        )

        registry.register(codex)
        registry.register(openCode)

        let manager = AIProviderManager(registry: registry)
        manager.start()

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.snapshots[.codex]?.status, .ready)
        XCTAssertEqual(manager.snapshots[.openCodeGo]?.status, .ready)
        XCTAssertEqual(manager.activePrimaryID, .codex)
        XCTAssertEqual(manager.primaryCompactMetric.value, "84%")
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
        let openCodeWindow = AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 40)
        let openCode = MockTestProvider(
            id: .openCodeGo,
            displayName: "OpenCode Go",
            status: .ready,
            metrics: [.usageWindow(openCodeWindow)],
            compactMetric: AICompactMetric(label: "OpenCode Go", value: "60%", secondaryValue: "5h", severity: .normal)
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
        XCTAssertEqual(manager.primaryCompactMetric.value, "60%")
        XCTAssertEqual(manager.primaryDisplayName, "OpenCode Go")

        // Preferred setting was NOT overwritten
        XCTAssertEqual(manager.preferredPrimaryID, .codex)
    }

    func testDeepSeekPrimarySelectionAndPersistence() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(id: .codex, displayName: "Codex", status: .ready)
        let deepseekBalance = AIBalance(currency: "CNY", total: Decimal(string: "35.72")!)
        let deepseek = MockTestProvider(
            id: .deepseek,
            displayName: "DeepSeek",
            status: .ready,
            metrics: [.balance(deepseekBalance)],
            compactMetric: AICompactMetric(label: "DeepSeek", value: "¥35.72", secondaryValue: nil, severity: .normal)
        )

        registry.register(codex)
        registry.register(deepseek)

        let manager = AIProviderManager(registry: registry)
        manager.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Default primary is codex
        XCTAssertEqual(manager.preferredPrimaryID, .codex)

        // Set DeepSeek as Primary
        manager.setPrimaryProvider(.deepseek)
        XCTAssertEqual(manager.preferredPrimaryID, .deepseek)
        XCTAssertEqual(manager.activePrimaryID, .deepseek)
        XCTAssertEqual(manager.primaryCompactMetric.value, "¥35.72")

        // Check persistence
        let saved = UserDefaults.standard.string(forKey: "devnotch_preferred_primary_id")
        XCTAssertEqual(saved, "deepseek")

        // Recreate manager to verify persistence
        let newManager = AIProviderManager(registry: registry)
        XCTAssertEqual(newManager.preferredPrimaryID, .deepseek)
    }

    func testDeepSeekOfflineFallbackToCodex() async {
        let registry = AIProviderRegistry()
        let codex = MockTestProvider(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            compactMetric: AICompactMetric(label: "Codex", value: "84%", severity: .normal)
        )
        let deepseek = MockTestProvider(
            id: .deepseek,
            displayName: "DeepSeek",
            status: .unavailable(reason: "Network error")
        )

        registry.register(codex)
        registry.register(deepseek)

        let manager = AIProviderManager(registry: registry)
        manager.setPrimaryProvider(.deepseek)
        manager.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Preferred is deepseek, but it is offline
        XCTAssertEqual(manager.preferredPrimaryID, .deepseek)
        // Fallback to ready codex
        XCTAssertEqual(manager.activePrimaryID, .codex)
        XCTAssertEqual(manager.primaryCompactMetric.value, "84%")

        // Preference remains unchanged
        XCTAssertEqual(manager.preferredPrimaryID, .deepseek)
    }

    func testProviderRefreshErrorAndTimeoutIsolation() async {
        let registry = AIProviderRegistry()
        let failingProvider = MockTestProvider(
            id: .deepseek,
            displayName: "DeepSeek",
            status: .ready
        )
        failingProvider.shouldThrowOnRefresh = true

        let workingProvider = MockTestProvider(
            id: .codex,
            displayName: "Codex",
            status: .ready,
            compactMetric: AICompactMetric(label: "Codex", value: "72%", severity: .normal)
        )

        registry.register(failingProvider)
        registry.register(workingProvider)

        let manager = AIProviderManager(registry: registry)
        manager.refreshAll()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Working provider snapshot remains healthy and undisturbed
        XCTAssertEqual(manager.snapshots[.codex]?.status, .ready)
        XCTAssertEqual(manager.snapshots[.codex]?.compactMetric.value, "72%")
    }
}
