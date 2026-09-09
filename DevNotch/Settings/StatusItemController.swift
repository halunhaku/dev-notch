import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "StatusItem")

/// Controls the lifecycle and menu of the optional macOS status bar item.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let preferences: PreferencesStore
    private let manager: AIProviderManager
    private let onOpenNotch: () -> Void
    private let onOpenSettings: () -> Void

    private var cancellables = Set<AnyCancellable>()

    init(
        preferences: PreferencesStore,
        manager: AIProviderManager,
        onOpenNotch: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.manager = manager
        self.onOpenNotch = onOpenNotch
        self.onOpenSettings = onOpenSettings

        super.init()

        setupBindings()
        updateStatusItemVisibility()
    }

    private func setupBindings() {
        // Observe preference changes to show/hide menu bar icon
        preferences.$showMenuBarItem
            .sink { [weak self] _ in
                self?.updateStatusItemVisibility()
            }
            .store(in: &cancellables)

        preferences.$appLanguage
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)

        // Observe provider snapshot updates to keep menu updated
        manager.$snapshots
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    private static let statusItemImage: NSImage? = {
        guard
            let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
            let image = NSImage(contentsOf: url)
        else {
            logger.error("MenuBarIcon.svg is missing from the app bundle")
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = "Dev Notch"
        return image
    }()

    private func updateStatusItemVisibility() {
        if preferences.showMenuBarItem {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    button.image = Self.statusItemImage
                    button.toolTip = "Dev Notch"
                }

                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                self.statusItem = item
                logger.info("Attached Dev Notch Menu Bar Status Item")
                updateMenu()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
                logger.info("Removed Dev Notch Menu Bar Status Item per user preference")
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    private func updateMenu() {
        guard let item = statusItem, let menu = item.menu else { return }
        menu.removeAllItems()

        // 1. App Title Header
        let titleItem = NSMenuItem(title: "Dev Notch", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        // 2. Active Enabled Providers Overview
        var addedAny = false
        for id in manager.providerIDs {
            guard preferences.isProviderEnabled(id) else { continue }
            if let snapshot = manager.snapshots[id] {
                let title = formatProviderMenuItem(snapshot: snapshot)
                let providerItem = NSMenuItem(title: title, action: #selector(openNotchAction), keyEquivalent: "")
                providerItem.target = self
                menu.addItem(providerItem)
                addedAny = true
            }
        }

        if !addedAny {
            let emptyItem = NSMenuItem(title: t("No active providers"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        menu.addItem(.separator())

        // 3. Actions
        let openNotch = NSMenuItem(title: t("Open Dev Notch"), action: #selector(openNotchAction), keyEquivalent: "o")
        openNotch.target = self
        menu.addItem(openNotch)

        let refreshTitle = manager.isRefreshing ? t("Refreshing…") : t("Refresh All")
        let refreshItem = NSMenuItem(title: refreshTitle, action: #selector(refreshAllAction), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !manager.isRefreshing
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: t("Settings…"), action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: t("Quit Dev Notch"), action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func formatProviderMenuItem(snapshot: AIProviderSnapshot) -> String {
        let name = snapshot.displayName
        let compact = snapshot.compactMetric

        if snapshot.status == .ready {
            return "\(name): \(compact.value)"
        } else {
            return "\(name): \(L10n.key(snapshot.status.shortDescription, locale: preferences.resolvedLocale))"
        }
    }

    private func t(_ key: String) -> String {
        L10n.key(key, locale: preferences.resolvedLocale)
    }

    @objc private func openNotchAction() {
        onOpenNotch()
    }

    @objc private func refreshAllAction() {
        manager.refreshAll()
    }

    @objc private func settingsAction() {
        onOpenSettings()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }
}
