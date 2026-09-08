import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AntigravityProvider")

/// AIProvider implementation for Google Antigravity (Desktop & CLI) with Live Activity support.
final class AntigravityProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .antigravity
    let displayName: String = "Google Antigravity"
    let refreshPolicy: AIProviderRefreshPolicy = .interval(300)

    let activityBridge = AntigravityActivityBridge()

    private let appLocator: AntigravityAppLocating
    private let lock = NSLock()

    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _installState: AntigravityInstallState = .notInstalled
    private var _authInfo: AntigravityAuthInfo = AntigravityAuthInfo()

    var onStateChanged: (@Sendable () -> Void)?

    init(appLocator: AntigravityAppLocating = DefaultAntigravityAppLocator()) {
        self.appLocator = appLocator
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

    var installState: AntigravityInstallState {
        lock.withLock { _installState }
    }

    var authInfo: AntigravityAuthInfo {
        lock.withLock { _authInfo }
    }

    var isLiveActivityInstalled: Bool {
        AntigravityIntegrationManager.isInstalled()
    }

    /// True when hooks are installed but reference an outdated helper path (own entries only).
    var liveActivityNeedsRepair: Bool {
        AntigravityIntegrationManager.needsRepair(expectedBridgePath: BundledHelperLocator.url(for: .activity).path)
    }

    func currentStatus() async -> AIProviderStatus {
        return status
    }

    /// Detects Antigravity CLI & Desktop and inspects user authentication.
    func start() async {
        updateStatus(.checking)
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

    /// Fetches all active metrics for Antigravity.
    func fetchMetrics() async -> [AIProviderMetric] {
        var metrics: [AIProviderMetric] = []
        if let context = activityBridge.contextMetric {
            metrics.append(.context(context))
        }
        return metrics
    }

    /// Produces concise display metric for Compact / Hovered notch states.
    func compactMetric() async -> AICompactMetric {
        let current = self.status
        guard current == .ready else {
            let severity: AICompactMetricSeverity = (current == .notAuthenticated) ? .warning : (current == .ready ? .normal : .inactive)
            return AICompactMetric(
                label: "Antigravity",
                value: current.shortDescription,
                secondaryValue: nil,
                severity: severity
            )
        }

        // 1. Transient Done state (lasts 3 seconds)
        if activityBridge.isTransientDone {
            return AICompactMetric(label: "Antigravity", value: "✓ Done", secondaryValue: nil, severity: .normal)
        }

        // 2. Active Working state
        let activity = activityBridge.activitySnapshot
        if activity.state == .working {
            return AICompactMetric(label: "Antigravity", value: "Working", secondaryValue: nil, severity: .normal)
        }

        // 3. Idle with Context
        if let context = activityBridge.contextMetric {
            let ctx = Int(round(context.usedPercent))
            let severity: AICompactMetricSeverity = ctx > 80 ? .warning : .normal
            return AICompactMetric(label: "Antigravity", value: "Ctx \(ctx)%", secondaryValue: nil, severity: severity)
        }

        return AICompactMetric(label: "Antigravity", value: "Ready", secondaryValue: nil, severity: .normal)
    }

    /// Refreshes install detection and authentication status.
    func refreshSnapshot() async {
        // 1. Detect CLI
        let cliPath = AntigravityExecutableLocator.locate()
        let cliVersion = cliPath.flatMap { AntigravityExecutableLocator.queryVersion(executablePath: $0) }

        // 2. Detect Desktop Application
        let isDesktop = appLocator.isAppInstalled()
        let appVersion = isDesktop ? appLocator.appVersion() : nil

        let state: AntigravityInstallState
        if let cli = cliVersion, isDesktop {
            state = .both(cliVersion: cli, appVersion: appVersion)
        } else if let cli = cliVersion {
            state = .cliOnly(cliVersion: cli)
        } else if isDesktop {
            state = .desktopOnly(appVersion: appVersion)
        } else {
            state = .notInstalled
        }

        guard state.isInstalled else {
            logger.info("Neither Antigravity CLI nor Desktop detected on this Mac")
            lock.withLock {
                self._installState = .notInstalled
                self._account = nil
            }
            updateStatus(.notInstalled)
            return
        }

        // 3. Inspect user authentication safely
        let auth = AntigravityAuthInspector.inspect()

        lock.withLock {
            self._installState = state
            self._authInfo = auth
            if auth.isAuthenticated {
                self._account = AIAccount(
                    email: auth.email,
                    planType: auth.modelName ?? "Google Account",
                    accountType: auth.authType ?? "oauth-personal"
                )
                self._status = .ready
            } else {
                self._account = AIAccount(email: nil, planType: "Free", accountType: "antigravity")
                self._status = .notAuthenticated
            }
        }

        // Also check if any existing bridge session data is on disk
        activityBridge.readSessionSnapshot()
        onStateChanged?()
    }

    /// Enables Dev Notch Live Activity by safely installing hooks in `~/.gemini/config/hooks.json`.
    func enableLiveActivity(
        bridgeBinaryPath: String? = nil,
        appBundleURL: URL = Bundle.main.bundleURL
    ) throws {
        try AppInstallation.requireStable(bundleURL: appBundleURL)
        let path = try bridgeBinaryPath
            ?? BundledHelperLocator.executablePath(for: .activity, bundleURL: appBundleURL)
        try AntigravityIntegrationManager.install(bridgeExecutablePath: path)
        onStateChanged?()
    }

    /// Disables Dev Notch Live Activity by removing solely Dev Notch hooks.
    func disableLiveActivity() throws {
        try AntigravityIntegrationManager.uninstall()
        onStateChanged?()
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }
}
