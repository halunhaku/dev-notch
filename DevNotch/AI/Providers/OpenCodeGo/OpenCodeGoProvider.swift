import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "OpenCodeGoProvider")

/// AIProvider implementation for OpenCode Go.
final class OpenCodeGoProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .openCodeGo
    let displayName: String = "OpenCode Go"

    private let lock = NSLock()
    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _usage: AIUsage?

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

    func fetchAccount() async throws -> AIAccount? {
        return account
    }

    func fetchUsage() async throws -> AIUsage? {
        return usage
    }

    /// Performs snapshot refresh without leaking or persisting tokens.
    func refreshSnapshot() async {
        // Read ephemeral credentials in memory only
        let apiKey = resolveOpenCodeApiKey()

        guard let key = apiKey, !key.isEmpty else {
            logger.info("OpenCode CLI is installed, but no OpenCode Go subscription credentials configured")
            lock.withLock {
                self._account = AIAccount(email: nil, planType: "Free", accountType: "opencode")
                self._usage = nil
            }
            updateStatus(.notAuthenticated)
            return
        }

        // Fetch usage from official Zen / Go endpoint
        do {
            let usageSnapshot = try await requestUsage(apiKey: key)
            lock.withLock {
                self._usage = usageSnapshot
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
        // 1. Environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENCODE_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // 2. ~/.local/share/opencode/auth.json
        let authPath = (("~/.local/share/opencode/auth.json" as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: authPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)) else {
            return nil
        }

        do {
            let json = try JSONDecoder().decode([String: OpenCodeLocalAuthEntry].self, from: data)
            // Look for opencode / opencodego / zen credentials
            if let entry = json["opencode"] ?? json["opencodego"] ?? json["zen"] ?? json["go"] {
                return entry.key ?? entry.token
            }
        } catch {
            logger.debug("Could not parse opencode auth.json: \(error.localizedDescription)")
        }

        return nil
    }

    /// Fetches usage payload from official endpoint.
    private func requestUsage(apiKey: String) async throws -> AIUsage {
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

    /// Maps OpenCode Go payload into generic AIUsage with 0...N windows.
    static func mapPayloadToUsage(_ payload: OpenCodeGoUsagePayload, now: Date = Date()) -> AIUsage {
        var windows: [AIUsageWindow] = []

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

        let credits = payload.balance.map {
            AICredits(balance: String(format: "$%.2f", $0), unlimited: false)
        }

        return AIUsage(
            windows: windows,
            credits: credits,
            planType: "Go Active",
            updatedAt: now
        )
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }
}
