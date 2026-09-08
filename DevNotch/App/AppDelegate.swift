import AppKit

/// Application delegate initializing and holding the lifecycle of NotchWindowController.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchWindowController()
        self.notchWindowController = controller
        controller.showNotchWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as an accessory overlay in the status/notch area
        return false
    }
}
