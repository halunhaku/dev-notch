import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AntigravityIntegration")

/// Manages safe registration of Dev Notch lifecycle hooks in `~/.gemini/config/hooks.json`.
struct AntigravityIntegrationManager: Sendable {
    static let defaultHooksURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/config/hooks.json")
    }()

    private static let hookIdentifier = "dev-notch-antigravity"

    /// Checks if Dev Notch hook configuration is currently active in hooks.json.
    static func isInstalled(hooksURL: URL = defaultHooksURL) -> Bool {
        guard FileManager.default.fileExists(atPath: hooksURL.path),
              let data = try? Data(contentsOf: hooksURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return json[hookIdentifier] != nil
    }

    /// Installs Dev Notch hooks into `hooks.json`, preserving all other named hooks.
    static func install(
        bridgeExecutablePath: String,
        hooksURL: URL = defaultHooksURL
    ) throws {
        var root: [String: Any] = [:]

        // 1. Read existing hooks.json if present
        if FileManager.default.fileExists(atPath: hooksURL.path),
           let data = try? Data(contentsOf: hooksURL) {
            if let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                root = parsed
            }
        }

        // 2. Build Antigravity hook specification
        // Note: PreInvocation, PostInvocation, Stop are flat; PreToolUse, PostToolUse use matcher groups.
        let devNotchSpec: [String: Any] = [
            "enabled": true,
            "PreInvocation": [
                [
                    "type": "command",
                    "command": "\"\(bridgeExecutablePath)\" antigravity PreInvocation",
                    "timeout": 5
                ]
            ],
            "PreToolUse": [
                [
                    "matcher": "*",
                    "hooks": [
                        [
                            "type": "command",
                            "command": "\"\(bridgeExecutablePath)\" antigravity PreToolUse",
                            "timeout": 5
                        ]
                    ]
                ]
            ],
            "PostToolUse": [
                [
                    "matcher": "*",
                    "hooks": [
                        [
                            "type": "command",
                            "command": "\"\(bridgeExecutablePath)\" antigravity PostToolUse",
                            "timeout": 5
                        ]
                    ]
                ]
            ],
            "PostInvocation": [
                [
                    "type": "command",
                    "command": "\"\(bridgeExecutablePath)\" antigravity PostInvocation",
                    "timeout": 5
                ]
            ],
            "Stop": [
                [
                    "type": "command",
                    "command": "\"\(bridgeExecutablePath)\" antigravity Stop",
                    "timeout": 5
                ]
            ]
        ]

        root[hookIdentifier] = devNotchSpec

        // 3. Write back atomically
        let dir = hooksURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let outputData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let tempURL = dir.appendingPathComponent("hooks_\(UUID().uuidString).tmp")
        try outputData.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(hooksURL, withItemAt: tempURL)

        logger.info("Successfully installed Dev Notch Antigravity hooks in: \(hooksURL.path)")
    }

    /// Removes solely the `dev-notch-antigravity` entry, preserving all user/plugin hooks.
    static func uninstall(hooksURL: URL = defaultHooksURL) throws {
        guard FileManager.default.fileExists(atPath: hooksURL.path),
              let data = try? Data(contentsOf: hooksURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        root.removeValue(forKey: hookIdentifier)

        let dir = hooksURL.deletingLastPathComponent()
        let outputData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let tempURL = dir.appendingPathComponent("hooks_\(UUID().uuidString).tmp")
        try outputData.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(hooksURL, withItemAt: tempURL)

        logger.info("Successfully uninstalled Dev Notch Antigravity hooks from: \(hooksURL.path)")
    }
}
