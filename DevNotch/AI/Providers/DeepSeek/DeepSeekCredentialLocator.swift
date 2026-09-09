import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "DeepSeekLocator")

/// Identifies where an AI credential was discovered.
enum AICredentialSource: String, Sendable {
    case environment = "Environment"
    case openCode = "OpenCode"
    case userConfigured = "Config"
    case grokCLI = "Grok CLI"
}

/// Ephemeral in-memory container for discovered DeepSeek API key.
struct DeepSeekCredential: Sendable {
    let apiKey: String
    let source: AICredentialSource
}

/// Locates DeepSeek API credentials safely across environment and local tools.
struct DeepSeekCredentialLocator: Sendable {
    static func locate(customAuthPath: String? = nil) -> DeepSeekCredential? {
        // 1. Environment variable
        if let envKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !envKey.isEmpty {
            logger.info("DeepSeek credential source: Environment")
            return DeepSeekCredential(apiKey: envKey, source: .environment)
        }

        // 2. OpenCode local credentials (~/.local/share/opencode/auth.json)
        let authPath = customAuthPath ?? (("~/.local/share/opencode/auth.json" as NSString).expandingTildeInPath)
        let url = URL(fileURLWithPath: authPath)

        if FileManager.default.fileExists(atPath: authPath),
           let data = try? Data(contentsOf: url) {
            do {
                let json = try JSONDecoder().decode([String: OpenCodeLocalAuthEntry].self, from: data)
                if let deepseekEntry = json["deepseek"], let key = deepseekEntry.key, !key.isEmpty {
                    logger.info("DeepSeek credential source: OpenCode")
                    return DeepSeekCredential(apiKey: key, source: .openCode)
                }
            } catch {
                logger.debug("Failed to decode opencode auth.json: \(error.localizedDescription)")
            }
        }

        return nil
    }
}
