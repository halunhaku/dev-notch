import Foundation

// MARK: - JSON-RPC 2.0 Base Protocol Types

struct JSONRPCRequest<P: Encodable & Sendable>: Encodable, Sendable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: P
}

struct JSONRPCNotification<P: Encodable & Sendable>: Encodable, Sendable {
    let jsonrpc: String = "2.0"
    let method: String
    let params: P
}

struct EmptyParams: Codable, Sendable {}

struct JSONRPCErrorPayload: Decodable, Error, Sendable {
    let code: Int
    let message: String
}

struct JSONRPCResponseEnvelope: Decodable, Sendable {
    let id: Int?
    let method: String?
    let error: JSONRPCErrorPayload?
}

// MARK: - Codex Initialize Models

struct CodexClientInfo: Codable, Sendable {
    let name: String
    let title: String
    let version: String
}

struct CodexInitializeParams: Codable, Sendable {
    let clientInfo: CodexClientInfo
}

struct CodexInitializeResult: Decodable, Sendable {
    let userAgent: String?
    let codexHome: String?
    let platformOs: String?
}

// MARK: - Codex Account Models

struct CodexAccountReadResult: Decodable, Sendable {
    let account: CodexAccountInfo?
    let requiresOpenaiAuth: Bool?
}

struct CodexAccountInfo: Decodable, Sendable {
    let type: String?
    let email: String?
    let planType: String?
}

// MARK: - Codex Rate Limits Models

struct CodexRateLimitsReadResult: Decodable, Sendable {
    let rateLimits: CodexRateLimitSnapshot?
}

struct CodexRateLimitsUpdatedParams: Decodable, Sendable {
    let rateLimits: CodexRateLimitSnapshot?
}

struct CodexRateLimitSnapshot: Decodable, Sendable {
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: Double?
}
