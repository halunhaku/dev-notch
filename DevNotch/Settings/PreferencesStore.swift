import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "Preferences")

/// Central observable preferences repository with UserDefaults persistence.
@MainActor
final class PreferencesStore: ObservableObject {
    // Keys
    private static let keyShowMenuBarItem = "devnotch_show_menu_bar_item"
    private static let keyGlobalHotkeyEnabled = "devnotch_global_hotkey_enabled"
    private static let keyGlobalHotkeyData = "devnotch_global_hotkey_data"
    private static let keyPreferredPrimaryID = "devnotch_preferred_primary_id"
    private static let keyTaskPulseEnabled = "devnotch_task_pulse_enabled"
    private static let keyShowCompletedActivity = "devnotch_show_completed_activity"
    private static let keyCompletedDisplayDuration = "devnotch_completed_display_duration"
    private static let keyAutoCollapseEnabled = "devnotch_auto_collapse_enabled"
    private static let keyProviderEnabled = "devnotch_provider_enabled_map"

    @Published var showMenuBarItem: Bool {
        didSet { UserDefaults.standard.set(showMenuBarItem, forKey: Self.keyShowMenuBarItem) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                try launchManager.setEnabled(launchAtLogin)
            } catch {
                logger.error("Failed to set launch at login: \(error.localizedDescription)")
            }
        }
    }

    @Published var globalHotkeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotkeyEnabled, forKey: Self.keyGlobalHotkeyEnabled) }
    }

    @Published var globalHotkey: KeyboardShortcutDefinition {
        didSet {
            if let data = try? JSONEncoder().encode(globalHotkey) {
                UserDefaults.standard.set(data, forKey: Self.keyGlobalHotkeyData)
            }
        }
    }

    @Published var preferredPrimaryProviderID: AIProviderID {
        didSet { UserDefaults.standard.set(preferredPrimaryProviderID.rawValue, forKey: Self.keyPreferredPrimaryID) }
    }

    @Published var taskPulseEnabled: Bool {
        didSet { UserDefaults.standard.set(taskPulseEnabled, forKey: Self.keyTaskPulseEnabled) }
    }

    @Published var showCompletedActivity: Bool {
        didSet { UserDefaults.standard.set(showCompletedActivity, forKey: Self.keyShowCompletedActivity) }
    }

    @Published var completedDisplayDuration: Double {
        didSet { UserDefaults.standard.set(completedDisplayDuration, forKey: Self.keyCompletedDisplayDuration) }
    }

    @Published var autoCollapseEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCollapseEnabled, forKey: Self.keyAutoCollapseEnabled) }
    }

    @Published private(set) var providerEnabled: [AIProviderID: Bool]

    private let launchManager: any LaunchAtLoginManaging

    init(launchManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager()) {
        let defaults = UserDefaults.standard
        self.launchManager = launchManager

        // Load showMenuBarItem (default: true)
        if defaults.object(forKey: Self.keyShowMenuBarItem) != nil {
            self.showMenuBarItem = defaults.bool(forKey: Self.keyShowMenuBarItem)
        } else {
            self.showMenuBarItem = true
        }

        // Sync launchAtLogin with system status
        self.launchAtLogin = launchManager.isEnabled

        // Global hotkey enabled (default: true)
        if defaults.object(forKey: Self.keyGlobalHotkeyEnabled) != nil {
            self.globalHotkeyEnabled = defaults.bool(forKey: Self.keyGlobalHotkeyEnabled)
        } else {
            self.globalHotkeyEnabled = true
        }

        // Global hotkey definition (default: ⌃⌥Space)
        if let data = defaults.data(forKey: Self.keyGlobalHotkeyData),
           let decoded = try? JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data) {
            self.globalHotkey = decoded
        } else {
            self.globalHotkey = .defaultToggleNotch
        }

        // Preferred Primary Provider (migrating Phase 3-6 key)
        if let raw = defaults.string(forKey: Self.keyPreferredPrimaryID),
           let parsed = AIProviderID(rawValue: raw) {
            self.preferredPrimaryProviderID = parsed
        } else {
            self.preferredPrimaryProviderID = .codex
        }

        // Task pulse enabled (default: true)
        if defaults.object(forKey: Self.keyTaskPulseEnabled) != nil {
            self.taskPulseEnabled = defaults.bool(forKey: Self.keyTaskPulseEnabled)
        } else {
            self.taskPulseEnabled = true
        }

        // Show completed activity (default: true)
        if defaults.object(forKey: Self.keyShowCompletedActivity) != nil {
            self.showCompletedActivity = defaults.bool(forKey: Self.keyShowCompletedActivity)
        } else {
            self.showCompletedActivity = true
        }

        // Completed display duration (default: 3.0s)
        let dur = defaults.double(forKey: Self.keyCompletedDisplayDuration)
        self.completedDisplayDuration = dur > 0 ? dur : 3.0

        // Auto collapse (default: true)
        if defaults.object(forKey: Self.keyAutoCollapseEnabled) != nil {
            self.autoCollapseEnabled = defaults.bool(forKey: Self.keyAutoCollapseEnabled)
        } else {
            self.autoCollapseEnabled = true
        }

        // Provider enabled map (default: all enabled)
        var map: [AIProviderID: Bool] = [:]
        let savedMap = defaults.dictionary(forKey: Self.keyProviderEnabled) as? [String: Bool] ?? [:]
        for id in AIProviderID.allCases {
            map[id] = savedMap[id.rawValue] ?? true
        }
        self.providerEnabled = map
    }

    /// Checks if a provider is enabled by user.
    func isProviderEnabled(_ id: AIProviderID) -> Bool {
        providerEnabled[id] ?? true
    }

    /// Toggles or sets provider enabled state.
    func setProviderEnabled(_ id: AIProviderID, enabled: Bool) {
        providerEnabled[id] = enabled
        var rawMap: [String: Bool] = [:]
        for (k, v) in providerEnabled {
            rawMap[k.rawValue] = v
        }
        UserDefaults.standard.set(rawMap, forKey: Self.keyProviderEnabled)
        logger.info("Provider \(id.rawValue) enabled state set to: \(enabled)")
    }
}
