import Foundation

enum ReleaseEnvironmentError: LocalizedError, Equatable {
    case unstableInstallLocation
    case bundledHelperMissing(String)

    var errorDescription: String? {
        switch self {
        case .unstableInstallLocation:
            return "Move Dev Notch to Applications first."
        case .bundledHelperMissing(let name):
            return "Required bundled helper is missing: \(name)"
        }
    }
}

enum AppInstallation {
    static func isStable(
        bundleURL: URL = Bundle.main.bundleURL,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let bundle = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplications = homeDirectoryURL
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        return bundle.pathExtension == "app"
            && (bundle.isDescendant(of: systemApplications) || bundle.isDescendant(of: userApplications))
    }

    static func requireStable(
        bundleURL: URL = Bundle.main.bundleURL,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        guard isStable(bundleURL: bundleURL, homeDirectoryURL: homeDirectoryURL) else {
            throw ReleaseEnvironmentError.unstableInstallLocation
        }
    }
}

enum BundledHelper: String, CaseIterable {
    case claude = "DevNotchClaudeBridge"
    case activity = "DevNotchActivityBridge"
    case nowPlaying = "DevNotchNowPlaying"
}

enum BundledHelperLocator {
    static func url(for helper: BundledHelper, bundleURL: URL = Bundle.main.bundleURL) -> URL {
        bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent(helper.rawValue, isDirectory: false)
    }

    static func executablePath(
        for helper: BundledHelper,
        bundleURL: URL = Bundle.main.bundleURL,
        fileManager: FileManager = .default
    ) throws -> String {
        let helperURL = url(for: helper, bundleURL: bundleURL)
        guard fileManager.isExecutableFile(atPath: helperURL.path) else {
            throw ReleaseEnvironmentError.bundledHelperMissing(helper.rawValue)
        }
        return helperURL.path
    }
}

enum BundleVersion {
    static func marketingVersion(infoDictionary: [String: Any]) -> String? {
        nonemptyString(infoDictionary["CFBundleShortVersionString"])
    }

    static func buildNumber(infoDictionary: [String: Any]) -> String? {
        nonemptyString(infoDictionary["CFBundleVersion"])
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ShellCommand {
    static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Extracts the executable path from a hook command produced by `ShellCommand.quote`.
enum HookCommandParser {
    static func executablePath(in command: String) -> String? {
        let trimmed = command.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmed.first else { return nil }
        if first == "'" || first == "\"" {
            let body = trimmed.dropFirst()
            guard let end = body.firstIndex(of: first) else { return nil }
            let path = String(body[..<end])
            return path.isEmpty ? nil : path
        }
        guard let space = trimmed.firstIndex(of: " ") else {
            return trimmed.isEmpty ? nil : String(trimmed)
        }
        let path = String(trimmed[..<space])
        return path.isEmpty ? nil : path
    }
}

private extension URL {
    func isDescendant(of directory: URL) -> Bool {
        let directoryComponents = directory.standardizedFileURL.pathComponents
        let candidateComponents = standardizedFileURL.pathComponents
        return candidateComponents.count > directoryComponents.count
            && Array(candidateComponents.prefix(directoryComponents.count)) == directoryComponents
    }
}
