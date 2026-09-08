import Foundation

/// OpenCode Go quota and usage payload model.
struct OpenCodeGoUsagePayload: Codable, Sendable {
    let rollingUsage: OpenCodeGoWindow?
    let weeklyUsage: OpenCodeGoWindow?
    let monthlyUsage: OpenCodeGoWindow?
    let balance: Double?
    let renewsAt: Double?

    enum CodingKeys: String, CodingKey {
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
