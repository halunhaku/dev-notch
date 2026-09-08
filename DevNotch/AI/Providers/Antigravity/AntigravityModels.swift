import Foundation

/// Installation detection state for Google Antigravity Desktop and CLI.
enum AntigravityInstallState: Equatable, Sendable {
    case both(cliVersion: String, appVersion: String?)
    case cliOnly(cliVersion: String)
    case desktopOnly(appVersion: String?)
    case notInstalled

    var isInstalled: Bool {
        switch self {
        case .both, .cliOnly, .desktopOnly: return true
        case .notInstalled: return false
        }
    }

    var cliVersion: String? {
        switch self {
        case .both(let cli, _), .cliOnly(let cli): return cli
        case .desktopOnly, .notInstalled: return nil
        }
    }

    var isDesktopInstalled: Bool {
        switch self {
        case .both, .desktopOnly: return true
        case .cliOnly, .notInstalled: return false
        }
    }
}

/// Authentication and model configuration read safely from `~/.gemini/` without secret access.
struct AntigravityAuthInfo: Equatable, Sendable {
    let email: String?
    let authType: String?
    let modelName: String?
    let isAuthenticated: Bool

    init(
        email: String? = nil,
        authType: String? = nil,
        modelName: String? = nil,
        isAuthenticated: Bool = false
    ) {
        self.email = email
        self.authType = authType
        self.modelName = modelName
        self.isAuthenticated = isAuthenticated
    }
}
