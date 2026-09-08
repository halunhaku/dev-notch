import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "OpenCodeGoProvider")

/// AIProvider implementation for OpenCode Go.
final class OpenCodeGoProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .openCodeGo
    let displayName: String = "OpenCode Go"
    let refreshPolicy: AIProviderRefreshPolicy = .interval(300)

    private let lock = NSLock()
    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _usage: AIUsage?
    private var _credits: AICredits?

    var onStateChanged: (@Sendable () -> Void)?

    var status: AIProviderStatus {
        lock.withLock { _status }
    }

    var account: AIAccount? {
        lock.withLock { _account }
    }

    var usage: AIUsage? {
        lock.withLock { _usage }
    }

    var credits: AICredits? {
        lock.withLock { _credits }
    }

    func currentStatus() async -> AIProviderStatus {
        return status
    }

    /// Initializes and checks OpenCode Go installation and authentication.
    func start() async {
        updateStatus(.checking)

        // 1. Detect binary
        guard let binaryPath = OpenCodeExecutableLocator.locate() else {
            logger.info("OpenCode executable not found")
            updateStatus(.notInstalled)
            return
        }

        logger.info("OpenCode executable detected at: \(binaryPath)")

        // 2. Refresh status and usage snapshot
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

    func fetchUsage() async throws -> AIUsage? {
        return usage
    }

    /// Fetches all active metrics for OpenCode Go.
    func fetchMetrics() async -> [AIProviderMetric] {
        var metrics: [AIProviderMetric] = []
        if let usage = self.usage {
            metrics.append(contentsOf: usage.windows.map { .usageWindow($0) })
        }
        if let credits = self.credits {
            metrics.append(.credits(credits))
        }
        return metrics
    }

    /// Produces concise display metric for Compact / Hovered notch states.
    func compactMetric() async -> AICompactMetric {
        let current = self.status
        guard current == .ready, let usage = self.usage else {
            let severity: AICompactMetricSeverity = (current == .notAuthenticated) ? .warning : (current == .ready ? .normal : .inactive)
            return AICompactMetric(
                label: displayName,
                value: current.shortDescription,
                secondaryValue: nil,
                severity: severity
            )
        }

        let targetWindow = usage.windows.first(where: { $0.id == "rolling" }) ?? usage.windows.first
        if let window = targetWindow {
            let remaining = Int(round(window.remainingPercent))
            let severity: AICompactMetricSeverity = remaining < 20 ? .warning : .normal
            return AICompactMetric(
                label: displayName,
                value: "\(remaining)%",
                secondaryValue: "5h",
                severity: severity
            )
        }

        return AICompactMetric(label: displayName, value: "Ready", severity: .normal)
    }

    /// Performs snapshot refresh without leaking or persisting tokens.
    func refreshSnapshot() async {
        let apiKey = resolveOpenCodeApiKey()

        guard let key = apiKey, !key.isEmpty else {
            logger.info("OpenCode CLI is installed, but no OpenCode Go subscription credentials configured")
            lock.withLock {
                self._account = AIAccount(email: nil, planType: "Free", accountType: "opencode")
                self._usage = nil
                self._credits = nil
            }
            updateStatus(.notAuthenticated)
            return
        }

        do {
            let (usageSnapshot, creditsSnapshot) = try await requestUsage(apiKey: key)
            lock.withLock {
                self._usage = usageSnapshot
                self._credits = creditsSnapshot
                self._account = AIAccount(email: nil, planType: "Go Active", accountType: "opencode")
            }
            updateStatus(.ready)
            logger.info("OpenCode Go usage updated successfully")
        } catch {
            logger.error("Failed to fetch OpenCode Go usage: \(error.localizedDescription)")
            updateStatus(.unavailable(reason: "Usage unavailable"))
        }
    }

    /// Inspects memory/config for OpenCode API key (without writing to disk or logs).
    private func resolveOpenCodeApiKey() -> String? {
        // 1. Check user-configured key in Dev Notch Settings
        if let userKey = PreferencesStore.getOpenCodeApiKey(), !userKey.isEmpty {
            return userKey
        }

        // 2. Check environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENCODE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        let authPath = (("~/.local/share/opencode/auth.json" as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: authPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)) else {
            return nil
        }

        do {
            let json = try JSONDecoder().decode([String: OpenCodeLocalAuthEntry].self, from: data)
            if let entry = json["opencode-go"] ?? json["opencode_go"] ?? json["opencode"] ?? json["opencodego"] ?? json["zen"] ?? json["go"] {
                return entry.key ?? entry.token
            }
        } catch {
            logger.debug("Could not parse opencode auth.json: \(error.localizedDescription)")
        }

        return nil
    }

    private func requestUsage(apiKey: String) async throws -> (AIUsage, AICredits?) {
        guard let url = URL(string: "https://opencode.ai/zen/go/v1/usage") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(OpenCodeGoUsagePayload.self, from: data)
        return Self.mapPayloadToUsage(payload)
    }

    static func mapPayloadToUsage(_ payload: OpenCodeGoUsagePayload, now: Date = Date()) -> (AIUsage, AICredits?) {
        var windows: [AIUsageWindow] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stdFormatter = ISO8601DateFormatter()

        // 1. Real official API envelope (payload.usage)
        if let real = payload.usage {
            if let rolling = real.rolling, let pct = rolling.percent {
                let reset = rolling.resetsAt.flatMap { isoFormatter.date(from: $0) ?? stdFormatter.date(from: $0) }
                windows.append(
                    AIUsageWindow(
                        id: "rolling",
                        label: "5 Hour",
                        durationMinutes: 300,
                        usedPercent: pct,
                        resetsAt: reset
                    )
                )
            }

            if let weekly = real.weekly, let pct = weekly.percent {
                let reset = weekly.resetsAt.flatMap { isoFormatter.date(from: $0) ?? stdFormatter.date(from: $0) }
                windows.append(
                    AIUsageWindow(
                        id: "weekly",
                        label: "Weekly",
                        durationMinutes: 10080,
                        usedPercent: pct,
                        resetsAt: reset
                    )
                )
            }

            if let monthly = real.monthly, let pct = monthly.percent {
                let reset = monthly.resetsAt.flatMap { isoFormatter.date(from: $0) ?? stdFormatter.date(from: $0) }
                windows.append(
                    AIUsageWindow(
                        id: "monthly",
                        label: "Monthly",
                        durationMinutes: 43200,
                        usedPercent: pct,
                        resetsAt: reset
                    )
                )
            }
        }

        // 2. Legacy mock format fallback
        if windows.isEmpty {
            if let rolling = payload.rollingUsage {
                let resetDate = rolling.resetInSec.map { now.addingTimeInterval(Double($0)) }
                windows.append(
                    AIUsageWindow(
                        id: "rolling",
                        label: "5 Hour",
                        durationMinutes: 300,
                        usedPercent: rolling.usagePercent,
                        resetsAt: resetDate
                    )
                )
            }

            if let weekly = payload.weeklyUsage {
                let resetDate = weekly.resetInSec.map { now.addingTimeInterval(Double($0)) }
                windows.append(
                    AIUsageWindow(
                        id: "weekly",
                        label: "Weekly",
                        durationMinutes: 10080,
                        usedPercent: weekly.usagePercent,
                        resetsAt: resetDate
                    )
                )
            }

            if let monthly = payload.monthlyUsage {
                let resetDate = monthly.resetInSec.map { now.addingTimeInterval(Double($0)) }
                windows.append(
                    AIUsageWindow(
                        id: "monthly",
                        label: "Monthly",
                        durationMinutes: 43200,
                        usedPercent: monthly.usagePercent,
                        resetsAt: resetDate
                    )
                )
            }
        }
        let credits = payload.balance.map {
            AICredits(balance: String(format: "$%.2f", $0), unlimited: false)
        }

        let usage = AIUsage(
            windows: windows,
            planType: "Go Active",
            updatedAt: now
        )

        return (usage, credits)
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }
}
