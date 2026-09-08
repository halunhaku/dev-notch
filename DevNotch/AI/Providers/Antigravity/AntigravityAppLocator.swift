import AppKit

protocol AntigravityAppLocating: Sendable {
    func isAppInstalled() -> Bool
    func appVersion() -> String?
}

/// Locates Google Antigravity Desktop application via macOS NSWorkspace and standard application directories.
struct DefaultAntigravityAppLocator: AntigravityAppLocating {
    static let bundleIdentifiers = [
        "com.google.antigravity",
        "com.google.antigravity.desktop",
        "com.google.gemini.antigravity"
    ]

    static let candidateAppPaths = [
        "/Applications/Antigravity.app",
        "/Applications/Google Antigravity.app",
        "~/Applications/Antigravity.app",
        "~/Applications/Google Antigravity.app"
    ]

    func isAppInstalled() -> Bool {
        return resolveAppURL() != nil
    }

    func appVersion() -> String? {
        guard let url = resolveAppURL(), let bundle = Bundle(url: url) else {
            return nil
        }
        return (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? (bundle.infoDictionary?["CFBundleVersion"] as? String)
    }

    private func resolveAppURL() -> URL? {
        // 1. Check via NSWorkspace bundle identifier lookup
        for bundleId in Self.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return url
            }
        }

        // 2. Check filesystem candidate paths
        let fm = FileManager.default
        for path in Self.candidateAppPaths {
            let expanded = (path as NSString).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }

        return nil
    }
}
