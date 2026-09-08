import AppKit
import os.log
import SwiftUI

/// Opens the SwiftUI `Settings` scene window programmatically.
///
/// macOS 14 deprecated the `showSettingsWindow:` AppKit selector, and macOS 26 blocks it
/// outright. The supported path is `@Environment(\.openSettings)`, which only resolves
/// inside an existing SwiftUI render tree. Menu bar/accessory apps therefore need a
/// hidden `Window` scene (`HiddenSettingsContextView`) that receives a notification and
/// invokes `openSettings`. Because macOS refuses to key a window without a Dock icon,
/// the activation policy is raised to `.regular` while Settings is open and restored to
/// `.accessory` when it closes.
@MainActor
enum SettingsOpener {
    static let openSettingsRequest = Notification.Name("devnotch.openSettingsRequest")

    /// Identifiers SwiftUI assigns to the Settings scene window across macOS versions.
    private static let settingsWindowIdentifiers: Set<String> = [
        "com_apple_SwiftUI_Settings_window",
        "com.apple.SwiftUI.Settings"
    ]

    private static var closeObserver: NSObjectProtocol?

    static func openSettings() {
        NSApp.setActivationPolicy(.regular)
        Task { @MainActor in
            // Give the Dock icon switch a runloop to take effect.
            try? await Task.sleep(for: .milliseconds(50))
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: openSettingsRequest, object: nil)

            // The Settings window is created asynchronously; poll briefly.
            var settingsWindow: NSWindow?
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(100))
                if let found = findSettingsWindow() {
                    settingsWindow = found
                    break
                }
            }

            guard let settingsWindow else {
                logger.error("Settings window did not appear after openSettings request")
                NSApp.setActivationPolicy(.accessory)
                return
            }

            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            installCloseObserver(for: settingsWindow)
        }
    }

    static func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            if let identifier = window.identifier?.rawValue,
               settingsWindowIdentifiers.contains(identifier) {
                return true
            }
            if window.isVisible, window.styleMask.contains(.titled),
               window.title.localizedCaseInsensitiveContains("settings")
                   || window.title.localizedCaseInsensitiveContains("preferences") {
                return true
            }
            if let controller = window.contentViewController,
               String(describing: type(of: controller)).contains("Settings") {
                return true
            }
            return false
        }
    }

    private static func installCloseObserver(for window: NSWindow) {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// 1x1 invisible window content that gives `@Environment(\.openSettings)` a live
/// SwiftUI render tree in an otherwise windowless accessory app.
struct HiddenSettingsContextView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: SettingsOpener.openSettingsRequest)) { _ in
                // One runloop delay avoids re-entrancy while the menu action unwinds.
                Task { @MainActor in
                    openSettings()
                }
            }
    }
}

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "SettingsOpener")
