import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "CodexProvider")

/// AIProvider implementation for OpenAI Codex CLI.
final class CodexProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .codex
    let displayName: String = "Codex"

    private let appServer = CodexAppServer()
    private let lock = NSLock()

    private var _status: AIProviderStatus = .checking
    private var _account: AIAccount?
    private var _usage: AIUsage?

    /// Callback invoked when usage or status updates in background.
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

    /// Initializes and starts the Codex app-server connection.
    func start() async {
        updateStatus(.checking)

        // 1. Locate codex binary
        guard let binaryPath = CodexExecutableLocator.locate() else {
            logger.warning("Codex binary not found on this system")
            updateStatus(.notInstalled)
            return
        }

        logger.info("Found Codex binary at: \(binaryPath)")

        // 2. Setup server event listeners
        await appServer.setNotificationHandler { [weak self] method, data in
            self?.handleNotification(method: method, data: data)
        }

        await appServer.setTerminationHandler { [weak self] exitCode in
            self?.handleTermination(exitCode: exitCode)
        }

        // 3. Launch process
        do {
            try await appServer.start(executablePath: binaryPath)
        } catch {
            logger.error("Failed to start CodexAppServer: \(error.localizedDescription)")
            updateStatus(.unavailable(reason: error.localizedDescription))
            return
        }

        // 4. Send initialize handshake
        do {
            let initParams = CodexInitializeParams(
                clientInfo: CodexClientInfo(
                    name: "dev-notch",
                    title: "Dev Notch",
                    version: "0.2.0"
                )
            )
            let initResult: CodexInitializeResult = try await appServer.sendRequest(
                method: "initialize",
                params: initParams
            )
            logger.info("Codex initialized successfully. User-agent: \(initResult.userAgent ?? "unknown")")

            // 5. Send initialized notification
            try await appServer.sendNotification(method: "initialized", params: EmptyParams())
        } catch {
            logger.error("Codex handshake failed: \(error.localizedDescription)")
            updateStatus(.unavailable(reason: "Initialize handshake failed"))
            return
        }

        // 6. Fetch initial account and rate limit snapshot
        await refreshSnapshot()
    }

    /// Graceful disconnect.
    func stop() async {
        await appServer.stop()
        updateStatus(.unavailable(reason: "Stopped"))
    }

    /// Fetches latest account details via `account/read`.
    func fetchAccount() async throws -> AIAccount? {
        let result: CodexAccountReadResult = try await appServer.sendRequest(
            method: "account/read",
            params: EmptyParams()
        )

        guard let acc = result.account else {
            return nil
        }

        return AIAccount(
            email: acc.email,
            planType: acc.planType,
            accountType: acc.type
        )
    }

    /// Fetches latest rate limits via `account/rateLimits/read`.
    func fetchUsage() async throws -> AIUsage? {
        let result: CodexRateLimitsReadResult = try await appServer.sendRequest(
            method: "account/rateLimits/read",
            params: EmptyParams()
        )

        guard let snapshot = result.rateLimits else {
            return nil
        }

        return mapSnapshotToUsage(snapshot)
    }

    /// Refreshes both account and rate limits snapshots.
    func refreshSnapshot() async {
        do {
            let fetchedAccount = try await fetchAccount()
            lock.withLock {
                self._account = fetchedAccount
            }

            if fetchedAccount == nil {
                logger.info("Codex has no active account logged in")
                updateStatus(.notAuthenticated)
                return
            }

            let fetchedUsage = try await fetchUsage()
            lock.withLock {
                self._usage = fetchedUsage
            }

            updateStatus(.ready)
            logger.info("Codex ready. Account: \(fetchedAccount?.email ?? "none"), Usage: \(fetchedUsage?.primaryRemainingInt ?? -1)%")
        } catch {
            logger.error("Error refreshing Codex snapshot: \(error.localizedDescription)")
            updateStatus(.error(message: error.localizedDescription))
        }
    }

    private func handleNotification(method: String, data: Data) {
        logger.debug("Received server notification: \(method)")

        if method == "account/rateLimits/updated" {
            do {
                let params = try JSONDecoder().decode(CodexRateLimitsUpdatedParams.self, from: data)
                if let snapshot = params.rateLimits {
                    let newUsage = mapSnapshotToUsage(snapshot)
                    lock.withLock {
                        self._usage = newUsage
                    }
                    onStateChanged?()
                    logger.info("Updated rate limits via notification: \(newUsage.primaryRemainingInt ?? -1)% remaining")
                }
            } catch {
                logger.error("Failed to decode account/rateLimits/updated: \(error.localizedDescription)")
            }
        } else if method == "account/updated" {
            Task {
                await refreshSnapshot()
            }
        }
    }

    private func handleTermination(exitCode: Int32) {
        updateStatus(.unavailable(reason: "Codex server exited (\(exitCode))"))
    }

    private func updateStatus(_ newStatus: AIProviderStatus) {
        lock.withLock {
            self._status = newStatus
        }
        onStateChanged?()
    }

    private func mapSnapshotToUsage(_ snapshot: CodexRateLimitSnapshot) -> AIUsage {
        var windows: [AIUsageWindow] = []

        if let primary = snapshot.primary {
            windows.append(
                AIUsageWindow(
                    id: "5h",
                    label: "5 Hour",
                    durationMinutes: primary.windowDurationMins,
                    usedPercent: primary.usedPercent,
                    resetsAt: primary.resetsAt.map { Date(timeIntervalSince1970: $0) }
                )
            )
        }

        if let secondary = snapshot.secondary {
            windows.append(
                AIUsageWindow(
                    id: "weekly",
                    label: "Weekly",
                    durationMinutes: secondary.windowDurationMins,
                    usedPercent: secondary.usedPercent,
                    resetsAt: secondary.resetsAt.map { Date(timeIntervalSince1970: $0) }
                )
            )
        }

        return AIUsage(
            windows: windows,
            credits: nil,
            planType: snapshot.planType,
            updatedAt: Date()
        )
    }
}

// Extension to allow setting callbacks on CodexAppServer
extension CodexAppServer {
    func setNotificationHandler(_ handler: (@Sendable (String, Data) -> Void)?) {
        self.onNotification = handler
    }

    func setTerminationHandler(_ handler: (@Sendable (Int32) -> Void)?) {
        self.onTermination = handler
    }
}
