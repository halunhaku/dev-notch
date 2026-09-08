import Foundation

/// Atomic file writer for local non-network IPC between external CLI hooks and Dev Notch.
struct ActivityIPCWriter: Sendable {
    static let baseDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DevNotch", isDirectory: true)
    }()

    static let activitiesDirectoryURL: URL = {
        baseDirectoryURL.appendingPathComponent("Activities", isDirectory: true)
    }()

    /// Appends a non-sensitive trace entry to `Activities/bridge.log`.
    static func logTrace(provider: String, message: String) {
        let logURL = activitiesDirectoryURL.appendingPathComponent("bridge.log")
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] [\(provider)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                defer { try? fileHandle.close() }
                _ = try? fileHandle.seekToEnd()
                try? fileHandle.write(contentsOf: data)
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    /// Writes a sanitized activity record atomically to `~/Library/Application Support/DevNotch/Activities/{providerID}.json`.
    static func write(record: SanitizedActivityRecord) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: activitiesDirectoryURL, withIntermediateDirectories: true)

        let targetURL = activitiesDirectoryURL.appendingPathComponent("\(record.providerID).json")
        let tempURL = activitiesDirectoryURL.appendingPathComponent("\(record.providerID)_\(UUID().uuidString).tmp")

        let data = try JSONEncoder().encode(record)
        try data.write(to: tempURL)
        _ = try fm.replaceItemAt(targetURL, withItemAt: tempURL)

        // Backward compatibility for Phase 5 Claude path
        if record.providerID == "claude" {
            let claudeDir = baseDirectoryURL.appendingPathComponent("Claude", isDirectory: true)
            try? fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            let claudeTarget = claudeDir.appendingPathComponent("session.json")
            let claudeTemp = claudeDir.appendingPathComponent("session_\(UUID().uuidString).tmp")
            try? data.write(to: claudeTemp)
            _ = try? fm.replaceItemAt(claudeTarget, withItemAt: claudeTemp)
        }
    }
}
