import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AntigravityAuth")

/// Safely inspects Antigravity account email and model configuration without accessing credentials.
struct AntigravityAuthInspector: Sendable {
    static let defaultGeminiDirURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini", isDirectory: true)
    }()

    static func inspect(geminiDir: URL = defaultGeminiDirURL) -> AntigravityAuthInfo {
        var email: String? = nil
        var authType: String? = nil
        var modelName: String? = nil

        let fm = FileManager.default

        // 1. Inspect google_accounts.json
        let accountsURL = geminiDir.appendingPathComponent("google_accounts.json")
        if fm.fileExists(atPath: accountsURL.path),
           let data = try? Data(contentsOf: accountsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let active = json["active"] as? String, !active.isEmpty {
                email = active
            }
        }

        // 2. Inspect settings.json (auth mode)
        let settingsURL = geminiDir.appendingPathComponent("settings.json")
        if fm.fileExists(atPath: settingsURL.path),
           let data = try? Data(contentsOf: settingsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let security = json["security"] as? [String: Any],
           let auth = security["auth"] as? [String: Any],
           let selected = auth["selectedType"] as? String {
            authType = selected
        }

        // 3. Inspect antigravity-cli/settings.json (configured model)
        let cliSettingsURL = geminiDir.appendingPathComponent("antigravity-cli/settings.json")
        if fm.fileExists(atPath: cliSettingsURL.path),
           let data = try? Data(contentsOf: cliSettingsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let model = json["model"] as? String {
            modelName = model
        }

        let isAuth = (email != nil)
        if isAuth {
            logger.info("Antigravity authenticated for user: \(email ?? ""), model: \(modelName ?? "")")
        } else {
            logger.info("Antigravity account status unavailable or not signed in")
        }

        return AntigravityAuthInfo(
            email: email,
            authType: authType ?? "oauth-personal",
            modelName: modelName ?? "Gemini 3.8 Flash (High)",
            isAuthenticated: isAuth
        )
    }
}
