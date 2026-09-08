import Foundation

/// Defines how often an AIProvider should refresh its metrics in background.
enum AIProviderRefreshPolicy: Equatable, Sendable {
    /// Periodic background polling interval in seconds.
    case interval(TimeInterval)
    /// Only refreshed on launch, notifications, or manual user action.
    case manualOnly
}

/// Unified protocol representing an AI provider integration.
protocol AIProvider: AnyObject, Sendable {
    var id: AIProviderID { get }
    var displayName: String { get }
    /// Declared background refresh policy for this provider.
    var refreshPolicy: AIProviderRefreshPolicy { get }

    /// Returns the current connectivity and authentication status.
    func currentStatus() async -> AIProviderStatus

    /// Connects to the provider and initializes background listeners.
    func start() async

    /// Gracefully stops processes and releases system resources.
    func stop() async

    /// Refreshes provider snapshots and metrics.
    func refresh() async

    /// Fetches the latest account profile.
    func fetchAccount() async throws -> AIAccount?

    /// Fetches all active metrics for this provider (Usage Windows, Balance, Credits).
    func fetchMetrics() async -> [AIProviderMetric]

    /// Produces a concise, presentation-ready metric for the Compact / Hovered notch states.
    func compactMetric() async -> AICompactMetric
}
