import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "GrokAuth")

/// Safe, non-secret account fields extracted from `~/.grok/auth.json`.
struct GrokAuthInfo: Equatable, Sendable {
    let email: String?
    let authMode: String?
    let expiresAt: Date?
    let isAuthenticated: Bool
    let credentialSource: AICredentialSource?

    init(
        email: String? = nil,
        authMode: String? = nil,
        expiresAt: Date? = nil,
        isAuthenticated: Bool = false,
        credentialSource: AICredentialSource? = nil
    ) {
        self.email = email
        self.authMode = authMode
        self.expiresAt = expiresAt
        self.isAuthenticated = isAuthenticated
        self.credentialSource = credentialSource
    }
}

/// Reads xAI Grok CLI session without logging tokens.
struct GrokCLISession: Sendable {
    let info: GrokAuthInfo
    let accessToken: String?
}

struct GrokAuthInspector: Sendable {
    static func inspect(customAuthPath: String? = nil) -> GrokAuthInfo {
        loadSession(customAuthPath: customAuthPath).info
    }

    static func loadSession(customAuthPath: String? = nil) -> GrokCLISession {
        let path = customAuthPath ?? (("~/.grok/auth.json" as NSString).expandingTildeInPath)
        if FileManager.default.fileExists(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let entries = try? JSONDecoder().decode([String: GrokAuthFileEntry].self, from: data) {
            let now = Date()
            for entry in entries.values {
                let expiry = GrokISO8601.parse(entry.expiresAt)
                let sessionValid = entry.hasRefreshableSession || (expiry.map { $0 > now } ?? false)
                guard sessionValid, entry.email != nil || entry.userId != nil else { continue }
                logger.info("Grok CLI session found")
                return GrokCLISession(
                    info: GrokAuthInfo(
                        email: entry.email,
                        authMode: entry.authMode,
                        expiresAt: expiry,
                        isAuthenticated: true,
                        credentialSource: .grokCLI
                    ),
                    accessToken: entry.accessToken
                )
            }
        }

        if customAuthPath == nil,
           let envKey = ProcessInfo.processInfo.environment["XAI_API_KEY"], !envKey.isEmpty {
            return GrokCLISession(
                info: GrokAuthInfo(
                    email: nil,
                    authMode: "api_key",
                    isAuthenticated: true,
                    credentialSource: .environment
                ),
                accessToken: envKey
            )
        }

        return GrokCLISession(info: GrokAuthInfo(), accessToken: nil)
    }
    static func parseISO8601(_ raw: String?) -> Date? {
        GrokISO8601.parse(raw)
    }
}

/// Decodes CLI auth entries. Bearer is held only for the in-memory billing request.
private struct GrokAuthFileEntry: Decodable {
    let authMode: String?
    let email: String?
    let expiresAt: String?
    let principalType: String?
    let userId: String?
    let hasRefreshableSession: Bool
    let accessToken: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case email
        case expiresAt = "expires_at"
        case principalType = "principal_type"
        case userId = "user_id"
        case refreshToken = "refresh_token"
        case key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authMode = try container.decodeIfPresent(String.self, forKey: .authMode)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        principalType = try container.decodeIfPresent(String.self, forKey: .principalType)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        let refresh = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        let key = try container.decodeIfPresent(String.self, forKey: .key)
        hasRefreshableSession = !(refresh?.isEmpty ?? true) || !(key?.isEmpty ?? true)
        accessToken = (key?.isEmpty == false) ? key : nil
    }
}
