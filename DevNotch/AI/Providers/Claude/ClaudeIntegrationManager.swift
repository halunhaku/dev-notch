import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "ClaudeIntegrationManager")

/// Manages safe, non-destructive registration of Dev Notch statusLine and hooks in `~/.claude/settings.json`.
struct ClaudeIntegrationManager: Sendable {
    static let defaultSettingsURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/settings.json")
    }()

    private static let devNotchTagKey = "_dev_notch"

    /// Checks if Dev Notch live activity hooks are currently active in settings.
    static func isInstalled(settingsURL: URL = defaultSettingsURL) -> Bool {
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        // Check if any hook array contains an entry with _dev_notch == true
        for (_, val) in hooks {
            if let arr = val as? [[String: Any]] {
                for item in arr {
                    if let tagged = item[devNotchTagKey] as? Bool, tagged == true {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Safely merges Dev Notch hooks into `settings.json`, preserving all unknown keys and user hooks.
    static func install(
        bridgeExecutablePath: String,
        settingsURL: URL = defaultSettingsURL
    ) throws {
        var root: [String: Any] = [:]

        // 1. Read existing settings if present
        if FileManager.default.fileExists(atPath: settingsURL.path),
           let data = try? Data(contentsOf: settingsURL) {
            if let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                root = parsed
            }
        }

        // 2. Prepare hooks dictionary
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]

        let targetEvents = [
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "PermissionRequest",
            "Stop",
            "SessionStart"
        ]

        for event in targetEvents {
            var eventList = (hooks[event] as? [[String: Any]]) ?? []
            // Filter out existing dev_notch entries
            eventList.removeAll { ($0[devNotchTagKey] as? Bool) == true }

            let devNotchEntry: [String: Any] = [
                devNotchTagKey: true,
                "hooks": [
                    [
                        "type": "command",
                        "command": "'\(bridgeExecutablePath)' '\(event)'"
                    ]
                ]
            ]
            eventList.append(devNotchEntry)
            hooks[event] = eventList
        }

        root["hooks"] = hooks

        // 3. Configure statusLine only if user has none, or if user already had our dev_notch statusLine
        if let existingStatusLine = root["statusLine"] as? [String: Any] {
            if (existingStatusLine[devNotchTagKey] as? Bool) == true {
                // Update our command
                root["statusLine"] = [
                    devNotchTagKey: true,
                    "type": "command",
                    "command": "'\(bridgeExecutablePath)' 'statusLine'"
                ]
            } else {
                logger.info("Existing custom user statusLine detected; preserving it and relying on hooks")
            }
        } else if root["statusLine"] == nil {
            root["statusLine"] = [
                devNotchTagKey: true,
                "type": "command",
                "command": "'\(bridgeExecutablePath)' 'statusLine'"
            ]
        }

        // 4. Write back atomically
        let dir = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let outputData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let tempURL = dir.appendingPathComponent("settings_\(UUID().uuidString).tmp")
        try outputData.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(settingsURL, withItemAt: tempURL)

        logger.info("Successfully installed Dev Notch Claude Code integration in: \(settingsURL.path)")
    }

    /// Removes solely Dev Notch entries from `settings.json`, leaving all user settings and third-party hooks intact.
    static func uninstall(settingsURL: URL = defaultSettingsURL) throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // 1. Remove dev_notch hooks
        if var hooks = root["hooks"] as? [String: Any] {
            for (event, val) in hooks {
                if var arr = val as? [[String: Any]] {
                    arr.removeAll { ($0[devNotchTagKey] as? Bool) == true }
                    if arr.isEmpty {
                        hooks.removeValue(forKey: event)
                    } else {
                        hooks[event] = arr
                    }
                }
            }
            if hooks.isEmpty {
                root.removeValue(forKey: "hooks")
            } else {
                root["hooks"] = hooks
            }
        }

        // 2. Remove statusLine only if it was ours
        if let statusLine = root["statusLine"] as? [String: Any],
           (statusLine[devNotchTagKey] as? Bool) == true {
            root.removeValue(forKey: "statusLine")
        }

        // 3. Write back atomically
        let dir = settingsURL.deletingLastPathComponent()
        let outputData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let tempURL = dir.appendingPathComponent("settings_\(UUID().uuidString).tmp")
        try outputData.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(settingsURL, withItemAt: tempURL)

        logger.info("Successfully uninstalled Dev Notch Claude Code integration from: \(settingsURL.path)")
    }
}
