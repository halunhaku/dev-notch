import AppKit
import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AppDelegate")

/// Application delegate coordinating Notch window, global hotkey, menu bar item, and preferences.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindowController: NotchWindowController?
    let preferences = PreferencesStore()
    lazy var providerManager = AIProviderManager()

    private var hotKeyManager: GlobalHotKeyManager?
    private var statusItemController: StatusItemController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI and background services when running under XCTest
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        // 1. Initialize Notch Window Controller
        let controller = NotchWindowController(
            providerManager: providerManager,
            preferences: preferences,
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            }
        )
        self.notchWindowController = controller
        controller.showNotchWindow()

        // 2. Initialize Status Bar Item
        self.statusItemController = StatusItemController(
            preferences: preferences,
            manager: providerManager,
            onOpenNotch: { [weak self] in
                self?.notchWindowController?.expand()
            },
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            }
        )

        // 3. Initialize Global Hotkey
        setupGlobalHotkey()

        // 4. Start AI Providers
        providerManager.start()

        // 5. Observe primary provider preference sync
        setupPreferenceBindings()
    }

    private func setupGlobalHotkey() {
        let hotKey = GlobalHotKeyManager()
        self.hotKeyManager = hotKey

        if preferences.globalHotkeyEnabled {
            hotKey.register(shortcut: preferences.globalHotkey) { [weak self] in
                self?.notchWindowController?.toggleExpansion()
            }
        }

        // Re-register whenever shortcut or toggle preference changes
        preferences.$globalHotkeyEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.hotKeyManager?.register(shortcut: self.preferences.globalHotkey) { [weak self] in
                        self?.notchWindowController?.toggleExpansion()
                    }
                } else {
                    self.hotKeyManager?.unregister()
                }
            }
            .store(in: &cancellables)

        preferences.$globalHotkey
            .sink { [weak self] newShortcut in
                guard let self = self, self.preferences.globalHotkeyEnabled else { return }
                self.hotKeyManager?.register(shortcut: newShortcut) { [weak self] in
                    self?.notchWindowController?.toggleExpansion()
                }
            }
            .store(in: &cancellables)
    }

    private func setupPreferenceBindings() {
        // Sync preferred primary provider from preferences to manager
        preferences.$preferredPrimaryProviderID
            .sink { [weak self] newPrimary in
                self?.providerManager.setPrimaryProvider(newPrimary)
            }
            .store(in: &cancellables)
    }

    /// Opens the native macOS Settings window and activates Dev Notch to the foreground.
    /// Uses SettingsOpener: the legacy `showSettingsWindow:` selector is blocked on macOS 26.
    func openSettingsWindow() {
        SettingsOpener.openSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
        providerManager.stop()
        logger.info("Dev Notch terminated cleanly")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
