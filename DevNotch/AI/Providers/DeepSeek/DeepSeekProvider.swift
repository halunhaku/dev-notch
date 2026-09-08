import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "DeepSeekProvider")

/// AIProvider implementation for DeepSeek API.
final class DeepSeekProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .deepseek
    let displayName: String = "DeepSeek"
    let refreshPolicy: AIProviderRefreshPolicy = .interval(600) // 10 minutes low frequency

    private let client: DeepSeekClient
    private let lock = NSLock()

    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _balances: [AIBalance] = []
    private var _credentialSource: AICredentialSource?
    private var _lastUpdated: Date?

    var onStateChanged: (@Sendable () -> Void)?

    init(client: DeepSeekClient = DeepSeekClient()) {
        self.client = client
    }

    var status: AIProviderStatus {
        lock.withLock { _status }
    }

    var account: AIAccount? {
        lock.withLock { _account }
    }

    var balances: [AIBalance] {
        lock.withLock { _balances }
    }

    var credentialSource: AICredentialSource? {
        lock.withLock { _credentialSource }
    }

    var lastUpdated: Date? {
        lock.withLock { _lastUpdated }
    }

    func currentStatus() async -> AIProviderStatus {
        return status
    }

    /// Initializes and fetches the DeepSeek balance.
    func start() async {
        updateStatus(.checking)

        // 1. Locate credentials
        guard let credential = DeepSeekCredentialLocator.locate() else {
            logger.info("DeepSeek credentials not found in environment or OpenCode config")
            lock.withLock {
                self._account = AIAccount(email: nil, planType: "Unconfigured", accountType: "deepseek")
                self._balances = []
                self._credentialSource = nil
            }
            updateStatus(.notAuthenticated)
            return
        }

        lock.withLock {
            self._credentialSource = credential.source
        }

        // 2. Refresh balance
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

    /// Fetches all active metrics (AIBalance instances) for DeepSeek.
    func fetchMetrics() async -> [AIProviderMetric] {
        let currentBalances = self.balances
        return currentBalances.map { .balance($0) }
    }

    /// Produces concise currency display metric for Compact / Hovered notch states.
    func compactMetric() async -> AICompactMetric {
        let current = self.status
        guard current == .ready, let primary = self.balances.first else {
            let severity: AICompactMetricSeverity = (current == .notAuthenticated) ? .warning : (current == .ready ? .normal : .inactive)
            return AICompactMetric(
                label: displayName,
                value: current.shortDescription,
                secondaryValue: nil,
                severity: severity
            )
        }

        let amountText = primary.formattedTotal
        let severity: AICompactMetricSeverity = primary.isAvailable ? .normal : .critical

        return AICompactMetric(
            label: displayName,
            value: amountText,
            secondaryValue: nil,
            severity: severity
        )
    }

    /// Refreshes balance snapshot from official DeepSeek endpoint.
    func refreshSnapshot() async {
        guard let credential = DeepSeekCredentialLocator.locate() else {
            lock.withLock {
                self._account = AIAccount(email: nil, planType: "Unconfigured", accountType: "deepseek")
                self._balances = []
            }
            updateStatus(.notAuthenticated)
            return
        }

        lock.withLock {
            self._credentialSource = credential.source
        }

        do {
            let response = try await client.fetchBalance(apiKey: credential.apiKey)

            var parsedBalances: [AIBalance] = []
            for info in response.balanceInfos {
                parsedBalances.append(
                    AIBalance(
                        currency: info.currency,
                        total: info.totalDecimal,
                        granted: info.grantedDecimal,
                        toppedUp: info.toppedUpDecimal,
                        isAvailable: response.isAvailable
                    )
                )
            }

            let now = Date()
            lock.withLock {
                self._balances = parsedBalances
                self._account = AIAccount(
                    email: nil,
                    planType: "API Platform",
                    accountType: "deepseek"
                )
                self._lastUpdated = now
            }

            updateStatus(.ready)
            logger.info("DeepSeek balance updated: \(parsedBalances.first?.formattedTotal ?? "none"), isAvailable=\(response.isAvailable)")
        } catch let apiError as DeepSeekAPIError {
            logger.error("DeepSeek API error: \(apiError.localizedDescription)")
            switch apiError {
            case .unauthorized:
                updateStatus(.notAuthenticated)
            case .insufficientBalance:
                updateStatus(.unavailable(reason: "Insufficient Balance"))
            case .rateLimited:
                updateStatus(.unavailable(reason: "Rate limited"))
            case .serverUnavailable(let code):
                updateStatus(.unavailable(reason: "Server unavailable (\(code))"))
            case .httpError(let code, let msg):
                updateStatus(.error(message: "HTTP \(code): \(msg)"))
            case .invalidResponse, .networkError:
                updateStatus(.unavailable(reason: apiError.localizedDescription))
            }
        } catch {
            logger.error("Unexpected error fetching DeepSeek balance: \(error.localizedDescription)")
            updateStatus(.error(message: error.localizedDescription))
        }
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }
}
