import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "GrokProvider")

/// AIProvider for the official xAI Grok Build CLI (`grok login`).
final class GrokProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .grok
    let displayName: String = "Grok"
    let refreshPolicy: AIProviderRefreshPolicy = .interval(180)

    private let lock = NSLock()
    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _authInfo = GrokAuthInfo()
    private var _credits: GrokCreditsSnapshot?
    private var _executablePath: String?

    var onStateChanged: (@Sendable () -> Void)?

    var status: AIProviderStatus {
        lock.withLock { _status }
    }

    var account: AIAccount? {
        lock.withLock { _account }
    }

    var authInfo: GrokAuthInfo {
        lock.withLock { _authInfo }
    }

    var executablePath: String? {
        lock.withLock { _executablePath }
    }

    var credentialSource: AICredentialSource? {
        lock.withLock { _authInfo.credentialSource }
    }

    func currentStatus() async -> AIProviderStatus {
        status
    }

    func start() async {
        updateStatus(.checking)
        guard let path = GrokExecutableLocator.locate() else {
            logger.info("Grok CLI executable not found")
            updateStatus(.notInstalled)
            return
        }
        lock.withLock { self._executablePath = path }
        logger.info("Grok CLI detected at: \(path)")
        await refreshSnapshot()
    }

    func stop() async {
        updateStatus(.unavailable(reason: "Stopped"))
    }

    func refresh() async {
        await refreshSnapshot()
    }

    func fetchAccount() async throws -> AIAccount? {
        account
    }

    func fetchMetrics() async -> [AIProviderMetric] {
        guard let credits = lock.withLock({ _credits }), let used = credits.usedPercent else {
            return []
        }
        let window = AIUsageWindow(
            id: AIUsageWindow.defaultId(for: credits.durationMinutes),
            label: credits.label,
            durationMinutes: credits.durationMinutes,
            usedPercent: used,
            resetsAt: credits.resetsAt
        )
        return [.usageWindow(window)]
    }

    func compactMetric() async -> AICompactMetric {
        switch status {
        case .ready:
            if let credits = lock.withLock({ _credits }), let used = credits.usedPercent {
                let remaining = Int(round(max(0, min(100, 100 - used))))
                let severity: AICompactMetricSeverity = remaining < 20 ? .warning : .normal
                let secondary: String
                switch credits.durationMinutes {
                case 10_080: secondary = "7d"
                case 43_200: secondary = "30d"
                default: secondary = credits.label
                }
                return AICompactMetric(label: displayName, value: "\(remaining)%", secondaryValue: secondary, severity: severity)
            }
            let value: String
            if let email = account?.email, let at = email.firstIndex(of: "@") {
                value = String(email[..<at])
            } else {
                value = account?.email ?? "Signed in"
            }
            return AICompactMetric(label: displayName, value: value, secondaryValue: "Grok", severity: .normal)
        case .notAuthenticated:
            return AICompactMetric(label: displayName, value: "Sign in", secondaryValue: nil, severity: .warning)
        case .notInstalled:
            return AICompactMetric(label: displayName, value: "Not Installed", secondaryValue: nil, severity: .inactive)
        case .checking:
            return AICompactMetric(label: displayName, value: "Checking…", secondaryValue: nil, severity: .inactive)
        case .unavailable, .error:
            return AICompactMetric(label: displayName, value: "Offline", secondaryValue: nil, severity: .critical)
        }
    }

    func refreshSnapshot() async {
        if GrokExecutableLocator.locate() == nil, executablePath == nil {
            updateStatus(.notInstalled)
            return
        }

        let session = GrokAuthInspector.loadSession()
        let info = session.info
        lock.withLock {
            self._authInfo = info
            self._credits = nil
        }

        guard info.isAuthenticated else {
            lock.withLock {
                self._account = AIAccount(email: nil, planType: "Not Signed In", accountType: "grok")
                self._status = .notAuthenticated
            }
            onStateChanged?()
            return
        }

        var plan: String
        if info.authMode == "oidc" {
            plan = "grok.com"
        } else if info.authMode == "api_key" {
            plan = "API Key"
        } else {
            plan = info.authMode ?? "Grok"
        }

        if let token = session.accessToken {
            do {
                let credits = try await GrokCreditsClient.fetch(accessToken: token)
                if let tier = credits.subscriptionTier, !tier.isEmpty {
                    plan = tier
                }
                lock.withLock { self._credits = credits }
            } catch GrokCreditsError.unauthorized {
                logger.info("Grok credits unauthorized; CLI session still present")
            } catch {
                logger.error("Grok credits fetch failed: \(error.localizedDescription)")
            }
        }

        lock.withLock {
            self._account = AIAccount(
                email: info.email,
                planType: plan,
                accountType: info.authMode ?? "grok"
            )
            self._status = .ready
        }
        onStateChanged?()
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock { self._status = newStatus }
        onStateChanged?()
    }
}
