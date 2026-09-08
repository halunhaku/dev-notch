import AppKit

/// Application delegate initializing and holding the lifecycle of NotchWindowController and AI providers.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindowController: NotchWindowController?
    let providerManager = AIProviderManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI and live background process launch when running under XCTest
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        let controller = NotchWindowController(providerManager: providerManager)
        self.notchWindowController = controller
        controller.showNotchWindow()

        // Start observing AI providers
        providerManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        providerManager.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as an accessory overlay in the status/notch area
        return false
    }
}
