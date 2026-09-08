import SwiftUI

/// Main entry point for Dev Notch macOS application.
@main
struct DevNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
