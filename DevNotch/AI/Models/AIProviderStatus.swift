import Foundation

/// Status of an AI provider connection and readiness.
enum AIProviderStatus: Equatable, Sendable {
    case checking
    case notInstalled
    case notAuthenticated
    case ready
    case unavailable(reason: String)
    case error(message: String)

    var shortDescription: String {
        switch self {
        case .checking: return "Checking…"
        case .notInstalled: return "Not Installed"
        case .notAuthenticated: return "Sign in required"
        case .ready: return "Ready"
        case .unavailable: return "Unavailable"
        case .error: return "Error"
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}
