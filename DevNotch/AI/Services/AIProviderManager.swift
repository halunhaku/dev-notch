import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AIProviderManager")

/// Central manager and observable state container for all AI providers.
@MainActor
final class AIProviderManager: ObservableObject {
    @Published var activeProviderID: AIProviderID = .codex
    @Published private(set) var status: AIProviderStatus = .checking
    @Published private(set) var account: AIAccount?
    @Published private(set) var usage: AIUsage?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing: Bool = false

    private let codexProvider = CodexProvider()
    private var refreshTimer: AnyCancellable?

    init() {
        setupBindings()
    }

    /// Primary remaining quota percentage for compact / hovered notch display.
    var primaryRemainingPercent: Double? {
        usage?.primaryRemainingPercent
    }

    /// Primary remaining percentage as an integer (0...100).
    var primaryRemainingInt: Int? {
        usage?.primaryRemainingInt
    }

    /// Display string for current status.
    var statusTitle: String {
        status.shortDescription
    }

    /// Initializes providers and begins observation.
    func start() {
        Task {
            logger.info("Starting AIProviderManager and initializing Codex provider")
            await codexProvider.start()
            syncFromProvider()
            setupPeriodicRefresh()
        }
    }

    /// Gracefully tears down all providers and timers.
    func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
        Task {
            await codexProvider.stop()
        }
    }

    /// Triggers an immediate refresh of account and rate limits.
    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            await codexProvider.refreshSnapshot()
            syncFromProvider()
            isRefreshing = false
        }
    }

    private func setupBindings() {
        codexProvider.onStateChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncFromProvider()
            }
        }
    }

    private func syncFromProvider() {
        self.status = codexProvider.status
        self.account = codexProvider.account
        self.usage = codexProvider.usage
        self.lastUpdated = codexProvider.usage?.updatedAt ?? Date()
    }

    private func setupPeriodicRefresh() {
        // Low-frequency fallback refresh (every 60 seconds)
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }
}
