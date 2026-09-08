import Foundation

// MARK: - Official CLI Auth Status Schema (`claude auth status --json`)

struct ClaudeAuthStatus: Decodable, Sendable {
    let loggedIn: Bool
    let authMethod: String?
    let apiProvider: String?
    let email: String?
    let orgId: String?
    let orgName: String?
    let subscriptionType: String?
    let apiKeySource: String?
}

/// Normalized authentication mode for Claude Code.
enum ClaudeAuthMode: Equatable, Sendable {
    case subscription(type: String, email: String?)
    case apiKey(source: String?)
    case unauthenticated
    case unknown(String)

    var displayTitle: String {
        switch self {
        case .subscription(let type, _):
            return "Claude \(type.capitalized)"
        case .apiKey:
            return "API Key"
        case .unauthenticated:
            return "Not Signed In"
        case .unknown(let method):
            return method
        }
    }
}

// MARK: - StatusLine & Hook Event Payloads

struct ClaudeContextWindowPayload: Codable, Sendable {
    let used_percentage: Double?
    let total_tokens: Int?
    let used_tokens: Int?
}

struct ClaudeStatusLinePayload: Codable, Sendable {
    let session_id: String?
    let cwd: String?
    let model: String?
    let cost: Double?
    let context_window: ClaudeContextWindowPayload?
    let hook_event_name: String?
}

// MARK: - IPC Bridge Message (Metadata-only, zero prompt/response capture)

struct ClaudeBridgeMessage: Codable, Sendable {
    let sessionID: String?
    let model: String?
    let projectName: String?
    let contextUsedPercent: Double?
    let sessionCostUSD: Decimal?
    let activityState: String
    let timestamp: Double

    init(
        sessionID: String? = nil,
        model: String? = nil,
        projectName: String? = nil,
        contextUsedPercent: Double? = nil,
        sessionCostUSD: Decimal? = nil,
        activityState: String = "idle",
        timestamp: Double = Date().timeIntervalSince1970
    ) {
        self.sessionID = sessionID
        self.model = model
        self.projectName = projectName
        self.contextUsedPercent = contextUsedPercent
        self.sessionCostUSD = sessionCostUSD
        self.activityState = activityState
        self.timestamp = timestamp
    }
}
