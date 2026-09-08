import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AIProviderManager")

/// Snapshot of an individual provider's current state and data.
struct AIProviderSnapshot: Identifiable, Equatable, Sendable {
    let id: AIProviderID
    let displayName: String
    let status: AIProviderStatus
    let account: AIAccount?
    let usage: AIUsage?
    let lastUpdated: Date?
    let errorMessage: String?

    var primaryRemainingPercent: Double? {
        usage?.primaryRemainingPercent
    }

    var primaryRemainingInt: Int? {
        usage?.primaryRemainingInt
    }
}

/// Central manager coordinating multi-provider lifecycle, status isolation,
/// and primary provider selection with automatic runtime fallback.
@MainActor
final class AIProviderManager: ObservableObject {
    private static let primaryPreferenceKey = "devnotch_preferred_primary_id"

    @Published private(set) var snapshots: [AIProviderID: AIProviderSnapshot] = [:]
    @Published private(set) var providerIDs: [AIProviderID] = []
    @Published private(set) var preferredPrimaryID: AIProviderID = .codex
    @Published private(set) var isRefreshing: Bool = false

    private let registry: AIProviderRegistry
    private var refreshTimer: AnyCancellable?

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
                usage: nil,
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

    var primaryRemainingPercent: Double? {
        primarySnapshot?.primaryRemainingPercent
    }

    var primaryRemainingInt: Int? {
        primarySnapshot?.primaryRemainingInt
    }

    var primaryDisplayName: String {
        primarySnapshot?.displayName ?? activePrimaryID.displayName
    }

    var primaryStatus: AIProviderStatus {
        primarySnapshot?.status ?? .checking
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
        setupPeriodicRefresh()
    }

    /// Stops all providers and cancels timers.
    func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
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
            if let codex = provider as? CodexProvider {
                await codex.refreshSnapshot()
            } else if let openCode = provider as? OpenCodeGoProvider {
                await openCode.refreshSnapshot()
            }
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
                        do {
                            if let codex = provider as? CodexProvider {
                                await codex.refreshSnapshot()
                            } else if let openCode = provider as? OpenCodeGoProvider {
                                await openCode.refreshSnapshot()
                            }
                            await self.updateSnapshot(for: provider.id)
                        }
                    }
                }
            }
            isRefreshing = false
        }
    }

    // MARK: - Internal Synchronization

    private func setupBindings() {
        for provider in registry.allProviders {
            if let codex = provider as? CodexProvider {
                codex.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: .codex)
                    }
                }
            } else if let openCode = provider as? OpenCodeGoProvider {
                openCode.onStateChanged = { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.updateSnapshot(for: .openCodeGo)
                    }
                }
            }
        }
    }

    private func updateSnapshot(for id: AIProviderID) async {
        guard let provider = registry.provider(for: id) else { return }

        let status = await provider.currentStatus()
        let account = try? await provider.fetchAccount()
        let usage = try? await provider.fetchUsage()

        var errorMsg: String? = nil
        if case .error(let msg) = status {
            errorMsg = msg
        } else if case .unavailable(let reason) = status {
            errorMsg = reason
        }

        self.snapshots[id] = AIProviderSnapshot(
            id: id,
            displayName: provider.displayName,
            status: status,
            account: account,
            usage: usage,
            lastUpdated: usage?.updatedAt ?? Date(),
            errorMessage: errorMsg
        )
    }

    private func setupPeriodicRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshAll()
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
