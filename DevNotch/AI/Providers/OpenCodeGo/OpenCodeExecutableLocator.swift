import Foundation

/// Locates the `opencode` binary across system paths, Homebrew, and shell environment.
struct OpenCodeExecutableLocator: Sendable {
    static let candidatePaths: [String] = [
        "/opt/homebrew/bin/opencode",
        "/usr/local/bin/opencode",
        "~/.local/bin/opencode",
        "~/.cargo/bin/opencode",
        "/usr/bin/opencode"
    ]

    static func locate() -> String? {
        let fileManager = FileManager.default

        // 1. Check known candidate paths
        for path in candidatePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        // 2. Check PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = (String(dir) as NSString).appendingPathComponent("opencode")
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 3. Fallback: query user's login shell
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-l", "-c", "which opencode"]
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
            // Ignore probe errors and fall through
        }

        return nil
    }
}
