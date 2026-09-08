import SwiftUI

/// Main entry point for Dev Notch macOS application.
@main
struct DevNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Must be declared before the Settings scene: the hidden window provides the
        Window("DevNotchHiddenContext", id: "HiddenSettingsContext") {
            HiddenSettingsContextView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

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
