import Foundation

/// Locates the `claude` binary across system paths, Homebrew, NVM, and shell environments.
struct ClaudeExecutableLocator: Sendable {
    static let candidatePaths: [String] = [
        "/opt/homebrew/bin/claude",
        "~/.local/bin/claude",
        "/usr/local/bin/claude",
        "~/.cargo/bin/claude",
        "/usr/bin/claude"
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

        // 2. Check NVM node bin directories
        let nvmDir = (("~/.nvm/versions/node" as NSString).expandingTildeInPath)
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmDir) {
            for ver in versions {
                let candidate = "\(nvmDir)/\(ver)/bin/claude"
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 3. Check PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = (String(dir) as NSString).appendingPathComponent("claude")
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 4. Fallback: query user's login shell
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-l", "-c", "which claude"]
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
