import Foundation

/// Unique identifier for an AI provider.
enum AIProviderID: String, CaseIterable, Codable, Hashable, Sendable {
    case codex = "codex"
    case claude = "claude"
    case antigravity = "antigravity"
    case openCodeGo = "opencode_go"
    case deepseek = "deepseek"
    case grok = "grok"

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        case .antigravity: return "Google Antigravity"
        case .openCodeGo: return "OpenCode Go"
        case .deepseek: return "DeepSeek"
        case .grok: return "Grok"
        }
    }
}
