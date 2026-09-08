import Foundation

/// Central registry managing available AIProvider instances.
final class AIProviderRegistry: @unchecked Sendable {
    private var providers: [AIProviderID: any AIProvider] = [:]
    private var order: [AIProviderID] = []
    private let lock = NSLock()

    init() {}

    /// Registers an AIProvider instance.
    func register(_ provider: any AIProvider) {
        lock.withLock {
            if !order.contains(provider.id) {
                order.append(provider.id)
            }
            providers[provider.id] = provider
        }
    }

    /// Looks up a provider by its unique ID.
    func provider(for id: AIProviderID) -> (any AIProvider)? {
        lock.withLock {
            providers[id]
        }
    }

    /// Returns all registered providers in registration order.
    var allProviders: [any AIProvider] {
        lock.withLock {
            order.compactMap { providers[$0] }
        }
    }

    /// Default registry configured for the five providers shipped in v1.0.0.
    static func makeDefaultRegistry() -> AIProviderRegistry {
        let registry = AIProviderRegistry()
        registry.register(CodexProvider())
        registry.register(ClaudeProvider())
        registry.register(AntigravityProvider())
        registry.register(OpenCodeGoProvider())
        registry.register(DeepSeekProvider())
        return registry
    }
}
