import Foundation

/// Unified protocol representing an AI provider integration.
protocol AIProvider: AnyObject, Sendable {
    var id: AIProviderID { get }
    var displayName: String { get }

    /// Returns the current connectivity and authentication status.
    func currentStatus() async -> AIProviderStatus

    /// Connects to the provider and initializes background listeners.
    func start() async

    /// Gracefully stops processes and releases system resources.
    func stop() async

    /// Fetches the latest account profile.
    func fetchAccount() async throws -> AIAccount?

    /// Fetches the latest quota / rate limits snapshot.
    func fetchUsage() async throws -> AIUsage?
}
