import Foundation

/// Real OpenCode Go API window structure.
struct OpenCodeRealWindow: Codable, Sendable {
    let status: String?
    let percent: Double?
    let resetsAt: String?
}

/// Real OpenCode Go API usage envelope.
struct OpenCodeRealUsageEnvelope: Codable, Sendable {
    let rolling: OpenCodeRealWindow?
    let weekly: OpenCodeRealWindow?
    let monthly: OpenCodeRealWindow?
}

/// OpenCode Go quota and usage payload model (supports both real API and legacy format).
struct OpenCodeGoUsagePayload: Codable, Sendable {
    // Official API: nested inside "usage"
    let usage: OpenCodeRealUsageEnvelope?

    // Legacy mock format
    let rollingUsage: OpenCodeGoWindow?
    let weeklyUsage: OpenCodeGoWindow?
    let monthlyUsage: OpenCodeGoWindow?
    let balance: Double?
    let renewsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usage
        case rollingUsage
        case weeklyUsage
        case monthlyUsage
        case balance
        case renewsAt
    }
}

struct OpenCodeGoWindow: Codable, Sendable {
    let usagePercent: Double
    let resetInSec: Int?

    enum CodingKeys: String, CodingKey {
        case usagePercent
        case resetInSec
    }
}

/// Representation of ~/.local/share/opencode/auth.json credentials.
struct OpenCodeLocalAuthEntry: Codable, Sendable {
    let type: String?
    let key: String?
    let token: String?
}
