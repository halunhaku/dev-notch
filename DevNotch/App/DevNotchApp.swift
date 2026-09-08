import SwiftUI

/// Main entry point for Dev Notch macOS application.
@main
struct DevNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                manager: appDelegate.providerManager,
                onShortcutChanged: { newShortcut in
                    // Sync immediately
                    appDelegate.preferences.globalHotkey = newShortcut
                }
            )
        }
    }
}
