import Foundation

/// Locates the `agy` (Google Antigravity CLI) executable across macOS paths.
struct AntigravityExecutableLocator: Sendable {
    static let candidatePaths: [String] = [
        "~/.local/bin/agy",
        "/opt/homebrew/bin/agy",
        "/usr/local/bin/agy",
        "~/.cargo/bin/agy",
        "/usr/bin/agy"
    ]

    static func locate() -> String? {
        let fileManager = FileManager.default

        // 1. Check candidate paths
        for path in candidatePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        // 2. Check PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = (String(dir) as NSString).appendingPathComponent("agy")
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 3. Fallback: query user's login shell
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-l", "-c", "which agy"]
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

    /// Queries `agy --version` to extract version string.
    static func queryVersion(executablePath: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["--version"]

        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            // Return nil
        }
        return nil
    }
}
