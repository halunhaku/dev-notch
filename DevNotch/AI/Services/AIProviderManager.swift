import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AIProviderManager")

/// Snapshot of an individual provider's current state and generic metrics.
struct AIProviderSnapshot: Identifiable, Equatable, Sendable {
    let id: AIProviderID
    let displayName: String
    let status: AIProviderStatus
    let account: AIAccount?
    let metrics: [AIProviderMetric]
    let compactMetric: AICompactMetric
    let credentialSource: String?
    let isLiveActivityEnabled: Bool
    let lastUpdated: Date?
    let errorMessage: String?

    init(
        id: AIProviderID,
        displayName: String,
        status: AIProviderStatus,
        account: AIAccount?,
        metrics: [AIProviderMetric],
        compactMetric: AICompactMetric,
        credentialSource: String? = nil,
        isLiveActivityEnabled: Bool = false,
        lastUpdated: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.account = account
        self.metrics = metrics
        self.compactMetric = compactMetric
        self.credentialSource = credentialSource
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.lastUpdated = lastUpdated
        self.errorMessage = errorMessage
    }

    var primaryRemainingPercent: Double? {
        for metric in metrics {
            if case .usageWindow(let w) = metric {
                return w.remainingPercent
            }
        }
        return nil
    }

    var primaryRemainingInt: Int? {
        primaryRemainingPercent.map { Int(round($0)) }
    }
}

/// Central manager coordinating multi-provider lifecycle, generic metrics aggregation,
/// and primary provider selection with automatic runtime fallback.
@MainActor
final class AIProviderManager: ObservableObject {
    private static let primaryPreferenceKey = "devnotch_preferred_primary_id"

    @Published private(set) var snapshots: [AIProviderID: AIProviderSnapshot] = [:]
    @Published private(set) var providerIDs: [AIProviderID] = []
    @Published private(set) var preferredPrimaryID: AIProviderID = .codex
    @Published private(set) var isRefreshing: Bool = false

    private let registry: AIProviderRegistry
    private var refreshTimers: [AIProviderID: AnyCancellable] = [:]

    init(registry: AIProviderRegistry = AIProviderRegistry.makeDefaultRegistry()) {
        self.registry = registry
        self.providerIDs = registry.allProviders.map { $0.id }
        self.preferredPrimaryID = Self.loadPreferredPrimaryID()

        // Initialize snapshot placeholders
        for provider in registry.allProviders {
            snapshots[provider.id] = AIProviderSnapshot(
                id: provider.id,
                displayName: provider.displayName,
                status: .checking,
                account: nil,
                metrics: [],
                compactMetric: AICompactMetric(
                    label: provider.displayName,
                    value: "Checking…",
                    secondaryValue: nil,
                    severity: .inactive
                ),
                credentialSource: nil,
                isLiveActivityEnabled: false,
                lastUpdated: nil,
                errorMessage: nil
            )
        }

        setupBindings()
    }

    // MARK: - Primary Provider Resolution

    /// Active primary provider used for Compact and Hovered notch states.
    /// Follows priority: Preferred Ready -> Any First Ready -> Preferred (Non-ready).
    var activePrimaryID: AIProviderID {
        // 1. Preferred provider is ready
        if let preferredSnapshot = snapshots[preferredPrimaryID], preferredSnapshot.status.isReady {
            return preferredPrimaryID
        }

        // 2. Runtime fallback: first available ready provider
        for id in providerIDs {
            if let snapshot = snapshots[id], snapshot.status.isReady {
                return id
            }
        }

        // 3. Fallback: preferred provider even if checking/offline
        return preferredPrimaryID
    }

    /// Snapshot for the active primary provider.
    var primarySnapshot: AIProviderSnapshot? {
        snapshots[activePrimaryID]
    }

    /// Concise presentation metric for Compact and Hovered notch states.
    var primaryCompactMetric: AICompactMetric {
        primarySnapshot?.compactMetric ?? AICompactMetric(
            label: activePrimaryID.displayName,
            value: primaryStatus.shortDescription,
            secondaryValue: nil,
            severity: .inactive
        )
    }

    var primaryDisplayName: String {
        primarySnapshot?.displayName ?? activePrimaryID.displayName
    }

    var primaryStatus: AIProviderStatus {
        primarySnapshot?.status ?? .checking
    }

    /// Current live activity state of the active primary provider (drives Task Pulse).
    var activePrimaryActivityState: AIActivityState {
        if activePrimaryID == .claude,
           let claude = registry.provider(for: .claude) as? ClaudeProvider {
            return claude.activityBridge.activitySnapshot.state
        }
        if activePrimaryID == .antigravity,
           let agy = registry.provider(for: .antigravity) as? AntigravityProvider {
            return agy.activityBridge.activitySnapshot.state
        }
        return .idle
    }

    /// Transient completion indicator of the active primary provider (drives Task Pulse success flash).
    var activePrimaryIsTransientDone: Bool {
        if activePrimaryID == .claude,
           let claude = registry.provider(for: .claude) as? ClaudeProvider {
            return claude.activityBridge.isTransientDone
        }
        if activePrimaryID == .antigravity,
           let agy = registry.provider(for: .antigravity) as? AntigravityProvider {
            return agy.activityBridge.isTransientDone
        }
        return false
    }

    /// Explicitly updates the user's preferred Primary Provider and persists preference.
    func setPrimaryProvider(_ id: AIProviderID) {
        guard preferredPrimaryID != id else { return }
        preferredPrimaryID = id
        UserDefaults.standard.set(id.rawValue, forKey: Self.primaryPreferenceKey)
        logger.info("Preferred Primary Provider updated to: \(id.rawValue)")
    }

    // MARK: - Lifecycle

    /// Starts all registered providers.
    func start() {
        logger.info("Starting AIProviderManager for \(self.providerIDs.count) registered providers")
        for provider in registry.allProviders {
            Task {
                await provider.start()
                await self.updateSnapshot(for: provider.id)
            }
        }
        setupPeriodicRefreshes()
    }

    /// Stops all providers and cancels timers.
    func stop() {
        for (_, timer) in refreshTimers {
            timer.cancel()
        }
        refreshTimers.removeAll()

        for provider in registry.allProviders {
            Task {
                await provider.stop()
            }
        }
    }

    /// Refreshes a single provider with isolated error handling.
    func refresh(providerID: AIProviderID) {
        guard let provider = registry.provider(for: providerID) else { return }
        Task {
            await provider.refresh()
            await self.updateSnapshot(for: providerID)
        }
    }

    /// Concurrently refreshes all providers with strict failure isolation.
    func refreshAll() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            await withTaskGroup(of: Void.self) { group in
                for provider in self.registry.allProviders {
                    group.addTask {
                        await provider.refresh()
                        await self.updateSnapshot(for: provider.id)
                    }
                }
            }
            isRefreshing = false
        }
    }

    /// Toggles Claude Live Activity hooks in `~/.claude/settings.json`.
    func toggleClaudeLiveActivity() {
        guard let claude = registry.provider(for: .claude) as? ClaudeProvider else { return }
        do {
            if claude.isLiveActivityInstalled {
                try claude.disableLiveActivity()
            } else {
                try claude.enableLiveActivity()
            }
            Task {
                await self.updateSnapshot(for: .claude)
            }
        } catch {
            logger.error("Failed to toggle Claude Live Activity: \(error.localizedDescription)")
        }
    }

    /// Toggles Antigravity Live Activity hooks in `~/.gemini/config/hooks.json`.
    func toggleAntigravityLiveActivity() {
        guard let agy = registry.provider(for: .antigravity) as? AntigravityProvider else { return }
        do {
            if agy.isLiveActivityInstalled {
                try agy.disableLiveActivity()
            } else {
                try agy.enableLiveActivity()
            }
            Task {
                await self.updateSnapshot(for: .antigravity)
            }
        } catch {
            logger.error("Failed to toggle Antigravity Live Activity: \(error.localizedDescription)")
        }
    }

    // MARK: - Internal Synchronization

    private func setupBindings() {
        for provider in registry.allProviders {
            let pid = provider.id
            if let codex = provider as? CodexProvider {
                codex.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: pid)
                    }
                }
            } else if let openCode = provider as? OpenCodeGoProvider {
                openCode.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: pid)
                    }
                }
            } else if let deepSeek = provider as? DeepSeekProvider {
                deepSeek.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: pid)
                    }
                }
            } else if let claude = provider as? ClaudeProvider {
                claude.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: pid)
                    }
                }
            } else if let agy = provider as? AntigravityProvider {
                agy.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: pid)
                    }
                }
            }
        }
    }

    private func updateSnapshot(for id: AIProviderID) async {
        guard let provider = registry.provider(for: id) else { return }

        let status = await provider.currentStatus()
        let account = try? await provider.fetchAccount()
        let metrics = await provider.fetchMetrics()
        let compact = await provider.compactMetric()

        var errorMsg: String? = nil
        if case .error(let msg) = status {
            errorMsg = msg
        } else if case .unavailable(let reason) = status {
            errorMsg = reason
        }

        var credSource: String? = nil
        if let ds = provider as? DeepSeekProvider {
            credSource = ds.credentialSource.map { "via \($0.rawValue)" }
        }

        var liveActivityInstalled = false
        if let claude = provider as? ClaudeProvider {
            liveActivityInstalled = claude.isLiveActivityInstalled
        } else if let agy = provider as? AntigravityProvider {
            liveActivityInstalled = agy.isLiveActivityInstalled
        }

        self.snapshots[id] = AIProviderSnapshot(
            id: id,
            displayName: provider.displayName,
            status: status,
            account: account,
            metrics: metrics,
            compactMetric: compact,
            credentialSource: credSource,
            isLiveActivityEnabled: liveActivityInstalled,
            lastUpdated: Date(),
            errorMessage: errorMsg
        )
    }

    private func setupPeriodicRefreshes() {
        for (_, timer) in refreshTimers {
            timer.cancel()
        }
        refreshTimers.removeAll()

        for provider in registry.allProviders {
            let pid = provider.id
            if case .interval(let seconds) = provider.refreshPolicy {
                let timer = Timer.publish(every: seconds, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.refresh(providerID: pid)
                    }
                refreshTimers[pid] = timer
            }
        }
    }

    private static func loadPreferredPrimaryID() -> AIProviderID {
        if let raw = UserDefaults.standard.string(forKey: primaryPreferenceKey),
           let saved = AIProviderID(rawValue: raw) {
            return saved
        }
        return .codex
    }
}
