import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "ClaudeProvider")

/// AIProvider implementation for Anthropic Claude Code CLI with Live Activity Support.
final class ClaudeProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .claude
    let displayName: String = "Claude Code"
    let refreshPolicy: AIProviderRefreshPolicy = .interval(180)

    let activityBridge = ClaudeActivityBridge()

    private let lock = NSLock()
    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _authMode: ClaudeAuthMode = .unauthenticated
    private var _executablePath: String?

    var onStateChanged: (@Sendable () -> Void)?

    init() {
        activityBridge.onActivityChanged = { [weak self] in
            self?.onStateChanged?()
        }
    }

    var status: AIProviderStatus {
        lock.withLock { _status }
    }

    var account: AIAccount? {
        lock.withLock { _account }
    }

    var authMode: ClaudeAuthMode {
        lock.withLock { _authMode }
    }

    var executablePath: String? {
        lock.withLock { _executablePath }
    }

    var isLiveActivityInstalled: Bool {
        ClaudeIntegrationManager.isInstalled()
    }

    /// True when hooks are installed but reference an outdated helper path (own entries only).
    var liveActivityNeedsRepair: Bool {
        ClaudeIntegrationManager.needsRepair(expectedBridgePath: BundledHelperLocator.url(for: .claude).path)
    }

    func currentStatus() async -> AIProviderStatus {
        return status
    }

    /// Checks Claude installation and official auth status.
    func start() async {
        updateStatus(.checking)

        // 1. Locate executable
        guard let path = ClaudeExecutableLocator.locate() else {
            logger.info("Claude Code executable not found")
            updateStatus(.notInstalled)
            return
        }

        lock.withLock {
            self._executablePath = path
        }
        logger.info("Claude Code detected at: \(path)")

        // 2. Inspect authentication and refresh
        await refreshSnapshot()
    }

    func stop() async {
        updateStatus(.unavailable(reason: "Stopped"))
    }

    func refresh() async {
        await refreshSnapshot()
    }

    func fetchAccount() async throws -> AIAccount? {
        return account
    }

    /// Fetches all active metrics for Claude Code (Context Window & Session Cost).
    func fetchMetrics() async -> [AIProviderMetric] {
        var metrics: [AIProviderMetric] = []

        if let context = activityBridge.contextMetric {
            metrics.append(.context(context))
        }

        if let cost = activityBridge.sessionCostMetric {
            let mode = self.authMode
            // Only show session cost if using API Key mode
            if case .apiKey = mode {
                metrics.append(.sessionCost(cost))
            }
        }

        return metrics
    }

    /// Produces concise display metric for Compact / Hovered notch states.
    /// Prioritizes live activity state over idle context metric.
    func compactMetric() async -> AICompactMetric {
        let current = self.status
        guard current == .ready else {
            let severity: AICompactMetricSeverity = (current == .notAuthenticated) ? .warning : (current == .ready ? .normal : .inactive)
            return AICompactMetric(
                label: "Claude",
                value: current.shortDescription,
                secondaryValue: nil,
                severity: severity
            )
        }

        // 1. Transient Done state (lasts 3 seconds)
        if activityBridge.isTransientDone {
            return AICompactMetric(label: "Claude", value: "✓ Done", secondaryValue: nil, severity: .normal)
        }

        // 2. Active Working state (respecting presentation dwell duration)
        if activityBridge.presentationState == .working {
            return AICompactMetric(label: "Claude", value: "Working", secondaryValue: nil, severity: .normal)
        }
        // 3. Waiting for Approval
        if activityBridge.activitySnapshot.state == .waitingForApproval {
            return AICompactMetric(label: "Claude", value: "Approval", secondaryValue: nil, severity: .warning)
        }
        // 4. Idle with Context Window metric
        if let context = activityBridge.contextMetric {
            let ctx = Int(round(context.usedPercent))
            let severity: AICompactMetricSeverity = ctx > 80 ? .warning : .normal
            return AICompactMetric(
                label: "Claude",
                value: "Ctx \(ctx)%",
                secondaryValue: nil,
                severity: severity
            )
        }

        return AICompactMetric(label: "Claude", value: "Ready", secondaryValue: nil, severity: .normal)
    }

    /// Refreshes Claude auth status.
    func refreshSnapshot() async {
        guard let path = self.executablePath ?? ClaudeExecutableLocator.locate() else {
            updateStatus(.notInstalled)
            return
        }

        let (mode, _) = await ClaudeAuthInspector.inspect(executablePath: path)

        lock.withLock {
            self._authMode = mode
            switch mode {
            case .subscription(let type, let email):
                self._account = AIAccount(
                    email: email,
                    planType: type.capitalized,
                    accountType: "claude.ai"
                )
                self._status = .ready
            case .apiKey(let source):
                self._account = AIAccount(
                    email: nil,
                    planType: "API Key",
                    accountType: source ?? "Anthropic"
                )
                self._status = .ready
            case .unauthenticated:
                self._account = AIAccount(email: nil, planType: "Not Signed In", accountType: "claude")
                self._status = .notAuthenticated
            case .unknown(let method):
                self._account = AIAccount(email: nil, planType: method, accountType: "claude")
                self._status = .ready
            }
        }

        // Also check if any existing bridge session data is on disk
        activityBridge.readSessionSnapshot()
        onStateChanged?()
    }

    /// Enables Dev Notch Live Activity by safely integrating hooks in `~/.claude/settings.json`.
    func enableLiveActivity(
        bridgeBinaryPath: String? = nil,
        appBundleURL: URL = Bundle.main.bundleURL
    ) throws {
        try AppInstallation.requireStable(bundleURL: appBundleURL)
        let path = try bridgeBinaryPath
            ?? BundledHelperLocator.executablePath(for: .claude, bundleURL: appBundleURL)
        try ClaudeIntegrationManager.install(bridgeExecutablePath: path)
        onStateChanged?()
    }

    /// Disables Dev Notch Live Activity by removing solely Dev Notch hooks from `~/.claude/settings.json`.
    func disableLiveActivity() throws {
        try ClaudeIntegrationManager.uninstall()
        onStateChanged?()
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }
}
