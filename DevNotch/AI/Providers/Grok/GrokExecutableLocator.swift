import Foundation

/// Locates the official xAI `grok` CLI (Grok Build).
struct GrokExecutableLocator: Sendable {
    static let candidatePaths: [String] = [
        "~/.local/bin/grok",
        "/opt/homebrew/bin/grok",
        "/usr/local/bin/grok",
        "~/.cargo/bin/grok",
        "/usr/bin/grok"
    ]

    static func locate() -> String? {
        let fileManager = FileManager.default

        for path in candidatePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = (String(dir) as NSString).appendingPathComponent("grok")
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-l", "-c", "which grok"]
        let stdout = Pipe()
        probe.standardOutput = stdout
        probe.standardError = Pipe()

        do {
            try probe.run()
            probe.waitUntilExit()
            if probe.terminationStatus == 0 {
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !str.isEmpty, fileManager.isExecutableFile(atPath: str) {
                    return str
                }
            }
        } catch {
            // Fall through
        }

        return nil
    }
}
