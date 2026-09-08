import Foundation
import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "LaunchAtLogin")

/// Protocol defining the launch-at-login operations for testing abstraction.
protocol LaunchAtLoginManaging: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Native macOS 14+ SMAppService manager for registering Dev Notch as a login item.
struct DefaultLaunchAtLoginManager: LaunchAtLoginManaging {
    private let bundleURL: URL

    init(bundleURL: URL = Bundle.main.bundleURL) {
        self.bundleURL = bundleURL
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try AppInstallation.requireStable(bundleURL: bundleURL)
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
                logger.info("Successfully registered Dev Notch with SMAppService")
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                logger.info("Successfully unregistered Dev Notch from SMAppService")
            }
        }
    }
}
