import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "ClaudeAuthInspector")

/// Executes and parses official `claude auth status --json` output.
struct ClaudeAuthInspector: Sendable {
    static func inspect(executablePath: String) async -> (ClaudeAuthMode, ClaudeAuthStatus?) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["auth", "status", "--json"]

        // Augment PATH environment so node and Homebrew are found
        var env = ProcessInfo.processInfo.environment
        var pathDirs: [String] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            NSString(string: "~/.local/bin").expandingTildeInPath,
            NSString(string: "~/.cargo/bin").expandingTildeInPath,
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let nvmDir = NSString(string: "~/.nvm/versions/node").expandingTildeInPath
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for ver in versions {
                let bin = "\(nvmDir)/\(ver)/bin"
                if FileManager.default.fileExists(atPath: bin) {
                    pathDirs.insert(bin, at: 0)
                }
            }
        }

        if let existing = env["PATH"], !existing.isEmpty {
            pathDirs.append(existing)
        }
        env["PATH"] = pathDirs.joined(separator: ":")
        proc.environment = env

        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else {
                logger.info("Claude auth status returned empty output")
                return (.unauthenticated, nil)
            }

            let status = try JSONDecoder().decode(ClaudeAuthStatus.self, from: data)
            guard status.loggedIn else {
                logger.info("Claude Code is not logged in")
                return (.unauthenticated, status)
            }

            let method = status.authMethod ?? "unknown"
            if method == "claude.ai" {
                let type = status.subscriptionType ?? "Pro"
                logger.info("Claude Code logged in via subscription: \(type)")
                return (.subscription(type: type, email: status.email), status)
            } else if method == "api_key" {
                logger.info("Claude Code logged in via API key")
                return (.apiKey(source: status.apiKeySource), status)
            } else {
                logger.info("Claude Code logged in via other method: \(method)")
                return (.unknown(method), status)
            }
        } catch {
            logger.debug("Failed to inspect Claude auth status: \(error.localizedDescription)")
            return (.unauthenticated, nil)
        }
    }
}
